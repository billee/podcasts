// server.js
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});// server.js
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*", // Allow all origins for development/testing
    methods: ["GET", "POST"]
  }
});

const users = new Map(); // Store userId -> socket.id mapping
const activeCalls = new Map(); // Store ongoing calls: callerId -> calleeId

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  const userId = socket.handshake.query.userId;
  if (userId) {
    users.set(userId, socket.id);
    console.log(`User ${userId} mapped to socket ${socket.id}`);
    // Emit an event to the client to confirm their ID and status (optional but good for debugging)
    socket.emit('ready', { userId: userId, socketId: socket.id });
  } else {
    console.log('User connected without a userId query parameter.');
    socket.emit('error', { message: 'Missing userId in connection query' });
    socket.disconnect(true); // Disconnect if userId is not provided
    return;
  }

  // Handle a direct call initiation
  socket.on('make-direct-call', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId && data.toUserId !== userId) {
      console.log(`User ${userId} making direct call to ${data.toUserId} (socket: ${targetSocketId})`);
      // Store the active call to help with signaling
      activeCalls.set(userId, data.toUserId); // Caller to Callee
      activeCalls.set(data.toUserId, userId); // Callee to Caller (for easy lookup)

      io.to(targetSocketId).emit('incoming-direct-call', {
        callerId: userId,
        callerName: data.callerName,
        isVideo: data.isVideo,
        sdpOffer: data.sdpOffer // Pass the initial SDP offer
      });
      console.log(`Emitted 'incoming-direct-call' to ${data.toUserId}`);
    } else if (data.toUserId === userId) {
        console.log(`User ${userId} tried to call themselves.`);
        socket.emit('call-error', { message: 'Cannot call yourself.' });
    }
    else {
      console.log(`Target user ${data.toUserId} not found or not connected.`);
      socket.emit('call-error', { message: `User ${data.toUserId} is offline or not found.` });
    }
  });

  // Handle offer from caller
  socket.on('offer', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      console.log(`Relaying offer from ${userId} to ${data.toUserId}`);
      io.to(targetSocketId).emit('offer', {
        fromUserId: userId,
        sdpOffer: data.sdpOffer
      });
    } else {
      console.log(`Target user ${data.toUserId} not found for offer relay.`);
    }
  });

  // Handle answer from callee
  socket.on('answer', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      console.log(`Relaying answer from ${userId} to ${data.toUserId}`);
      io.to(targetSocketId).emit('answer', {
        fromUserId: userId,
        sdpAnswer: data.sdpAnswer
      });
    } else {
      console.log(`Target user ${data.toUserId} not found for answer relay.`);
    }
  });

  // Handle ICE candidates
  socket.on('candidate', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      console.log(`Relaying ICE candidate from ${userId} to ${data.toUserId}`);
      io.to(targetSocketId).emit('candidate', {
        fromUserId: userId,
        candidate: data.candidate
      });
    } else {
      console.log(`Target user ${data.toUserId} not found for candidate relay.`);
    }
  });

  // Handle call acceptance
  socket.on('accept-call', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      console.log(`User ${userId} accepting call from ${data.toUserId}`);
      io.to(targetSocketId).emit('call-accepted-by-callee', {
        calleeId: userId,
        sdpAnswer: data.sdpAnswer // Pass the initial SDP answer
      });
    }
  });

  // Handle call decline
  socket.on('decline-call', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      console.log(`User ${userId} declining call from ${data.toUserId}`);
      io.to(targetSocketId).emit('call-declined-by-callee', {
        calleeId: userId
      });
      // Clean up active call status
      activeCalls.delete(userId);
      activeCalls.delete(data.toUserId);
    }
  });

  // Handle end call
  socket.on('end-call', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      console.log(`User ${userId} ending call with ${data.toUserId}`);
      io.to(targetSocketId).emit('call-ended', {
        fromUserId: userId
      });
    }
    // Clean up active call status for both parties
    activeCalls.delete(userId);
    activeCalls.delete(data.toUserId);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
    // Find the userId associated with this socket.id and remove it
    let disconnectedUserId = null;
    for (let [key, value] of users.entries()) {
      if (value === socket.id) {
        disconnectedUserId = key;
        break;
      }
    }
    if (disconnectedUserId) {
      users.delete(disconnectedUserId);
      console.log(`User ${disconnectedUserId} (socket: ${socket.id}) removed from map.`);

      // Notify the other party if they were in an active call
      const otherUserIdInCall = activeCalls.get(disconnectedUserId);
      if (otherUserIdInCall) {
        const otherSocketId = users.get(otherUserIdInCall);
        if (otherSocketId) {
          io.to(otherSocketId).emit('partner-disconnected', {
            disconnectedUserId: disconnectedUserId
          });
          console.log(`Notified ${otherUserIdInCall} that ${disconnectedUserId} disconnected.`);
        }
        // Clean up active call for the other party too
        activeCalls.delete(otherUserIdInCall);
      }
      activeCalls.delete(disconnectedUserId);
    }
  });

  socket.on('audio-toggle', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
        io.to(targetSocketId).emit('audio-toggle', {
            fromUserId: userId,
            isMuted: data.isMuted
        });
    }
  });

  socket.on('video-toggle', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
        io.to(targetSocketId).emit('video-toggle', {
            fromUserId: userId,
            isVideoOff: data.isVideoOff
        });
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Signaling server running on port ${PORT}`);
});


const users = new Map(); // Store user connections

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);
  
  const userId = socket.handshake.query.userId;
  users.set(userId, socket.id);

  socket.on('make-call', (data) => {
    const targetSocketId = users.get(data.to);
    if (targetSocketId) {
      io.to(targetSocketId).emit('incoming-call', {
        callerId: userId,
        callerName: data.callerName,
        isVideo: data.isVideo
      });
    }
  });

  socket.on('accept-call', () => {
    // Handle call acceptance
    socket.broadcast.emit('call-accepted');
  });

  socket.on('decline-call', () => {
    socket.broadcast.emit('call-declined');
  });

  socket.on('end-call', () => {
    socket.broadcast.emit('call-ended');
  });

  socket.on('disconnect', () => {
    users.delete(userId);
    console.log('User disconnected:', socket.id);
  });

  socket.on('audio-toggle', (data) => {
    socket.broadcast.emit('audio-toggle', data);
  });

  socket.on('video-toggle', (data) => {
    socket.broadcast.emit('video-toggle', data);
  });



});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});