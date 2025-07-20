// web/video_player.js

class VideoPlayer {
  static register() {
    window.videoPlayerHandler = {
      registerViewFactory: (videoUrl) => {
        const iframe = document.createElement('iframe');
        iframe.src = videoUrl;
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.allowFullscreen = true;
        
        window.createVideoPlayer = () => iframe;
      }
    };
  }
}

VideoPlayer.register();