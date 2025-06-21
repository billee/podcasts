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