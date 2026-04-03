enum BtmProgressBehavior {
  alwaysShow('始终展示'),
  alwaysHide('始终隐藏'),
  onlyShowFullScreen('仅全屏时展示'),
  onlyHideFullScreen('仅全屏时隐藏'),
  ;

  final String desc;
  const BtmProgressBehavior(this.desc);
}
