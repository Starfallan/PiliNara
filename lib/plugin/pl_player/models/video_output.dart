// mpv --vo=help
enum VoType {
  gpu('gpu', 'GPU 视频输出'),
  gpuNext('gpu-next', 'GPU 视频输出 (实验性)'),
  xv('xv', 'XVideo (X11) (过时)'),
  x11('x11', 'X11 共享内存 (X11) (仅回退)'),
  vdpau('vdpau', 'VDPAU (X11)'),
  direct3d('direct3d', 'Direct3D (Windows)'),
  sdl('sdl', 'SDL 2.0+ (兼容性)'),
  dmabufWayland('dmabuf-wayland', 'Wayland 输出 (实验性)'),
  vaapi('vaapi', 'VAAPI (Linux)'),
  drm('drm', 'DRM (Linux)'),
  mediacodecEmbed('mediacodec_embed', 'MediaCodec 嵌入 (Android)'),
  wlshm('wlshm', 'Wayland 共享内存 (Wayland)')
  ;

  final String vo;
  final String desc;
  const VoType(this.vo, this.desc);
}
