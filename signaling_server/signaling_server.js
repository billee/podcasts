// server.js
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
const server = http.createServer(app);

// Use process.env.PORT for Heroku, or 3000 for local development
const port = process.env.PORT || 3000;

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', users: users.size, activeCalls: activeCalls.size });
});

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
    socket.disconnect(true); // Disconnect if userId is missing
    return;
  }

  socket.on('register', (registeredUserId) => {
    // This 'register' event is often redundant if userId is already in handshake query,
    // but good to have for re-registrations or if initial query fails for some reason.
    // Ensure the client sends the userId directly, not as an object.
    if (registeredUserId && registeredUserId === userId) { // Ensure consistency
      socket.join(registeredUserId);
      console.log(`User ${registeredUserId} explicitly registered with socket ID ${socket.id}`);
      io.emit('user_online', registeredUserId); // Notify others that this user is online
    } else {
      console.log(`Registration attempt for mismatched or missing ID: ${registeredUserId}`);
      socket.emit('error', { message: 'Registration failed: Mismatched or missing userId.' });
    }
  });


  socket.on('make-direct-call', async (data) => {
    const { toUserId, sdpOffer, isVideoCall, fromUserId } = data;
    console.log(`Direct call attempt from ${fromUserId} to ${toUserId}. Is Video: ${isVideoCall}`);

    const targetSocketId = users.get(toUserId);
    if (targetSocketId) {
      // Ensure the caller is not trying to call themselves or an active call already exists
      if (activeCalls.has(fromUserId) || activeCalls.has(toUserId)) {
        console.log(`Call conflict: ${fromUserId} or ${toUserId} already in a call.`);
        socket.emit('call-error', { message: 'One party is already in an active call.' });
        return;
      }

      // Track the active call
      activeCalls.set(fromUserId, toUserId);
      activeCalls.set(toUserId, fromUserId); // Bi-directional mapping

      io.to(targetSocketId).emit('incoming-direct-call', {
        callerId: fromUserId,
        callerName: fromUserId, // You might want to pass actual name from DB here
        isVideo: isVideoCall,
        sdpOffer: sdpOffer
      });
      console.log(`Emitted 'incoming-direct-call' to ${toUserId}`);
    } else {
      console.log(`User ${toUserId} is not online.`);
      socket.emit('call-error', { message: `User ${toUserId} is not online.` });
    }
  });

  socket.on('accept-direct-call', (data) => {
    const { toUserId, sdpAnswer, fromUserId } = data; // fromUserId is the callee
    console.log(`Call accepted by ${fromUserId} to ${toUserId}`);

    const targetSocketId = users.get(toUserId); // This is the caller's socket ID
    if (targetSocketId) {
      io.to(targetSocketId).emit('call-accepted-by-callee', {
        calleeId: fromUserId,
        sdpAnswer: sdpAnswer // Send the answer back to the caller
      });
      console.log(`Emitted 'call-accepted-by-callee' to ${toUserId}`);
    } else {
      console.log(`Caller ${toUserId} is no longer online.`);
      // Optionally clean up activeCalls for fromUserId here if caller disconnected
      socket.emit('call-error', { message: `Caller ${toUserId} is no longer online.` });
      activeCalls.delete(fromUserId);
    }
  });

  socket.on('decline-direct-call', (data) => {
    const { toUserId, fromUserId } = data; // fromUserId is the callee
    console.log(`Call declined by ${fromUserId} for ${toUserId}`);

    const targetSocketId = users.get(toUserId); // This is the caller's socket ID
    if (targetSocketId) {
      io.to(targetSocketId).emit('call-declined-by-callee', {
        calleeId: fromUserId,
      });
      console.log(`Emitted 'call-declined-by-callee' to ${toUserId}`);
    } else {
      console.log(`Caller ${toUserId} is no longer online.`);
    }
    // Clean up the active call mapping for both parties
    activeCalls.delete(fromUserId);
    activeCalls.delete(toUserId);
  });

  socket.on('offer', (data) => {
    // This is typically for re-negotiation or direct offer passing, if not part of initial make-direct-call
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('offer', {
        sdpOffer: data.sdpOffer,
        fromUserId: userId // Ensure fromUserId is consistent (the sender's userId)
      });
    }
  });

  socket.on('answer', (data) => {
    // This is typically for re-negotiation or direct answer passing
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('answer', {
        sdpAnswer: data.sdpAnswer,
        fromUserId: userId // Ensure fromUserId is consistent (the sender's userId)
      });
    }
  });

  socket.on('candidate', (data) => {
    const targetSocketId = users.get(data.toUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('candidate', {
        candidate: data.candidate,
        fromUserId: userId
      });
    }
  });

  socket.on('end-call', (data) => {
    const { toUserId, fromUserId } = data;
    console.log(`End call request from ${fromUserId} to ${toUserId}`);

    const targetSocketId = users.get(toUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('call-ended', { fromUserId: fromUserId });
    } else {
      console.log(`Target user ${toUserId} not online to receive call-ended.`);
    }
    // Clean up active call mapping for both parties
    activeCalls.delete(fromUserId);
    activeCalls.delete(toUserId);
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


  socket.on('disconnect', (reason) => {
    console.log('User disconnected:', socket.id, 'Reason:', reason);
    // Find the userId associated with this disconnected socket.id
    let disconnectedUserId = null;
    for (const [key, value] of users.entries()) {
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
});

server.listen(port, () => {
  console.log(`Signaling server listening on port ${port}`);
});