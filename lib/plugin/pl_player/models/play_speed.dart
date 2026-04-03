enum PlaySpeed {
  pointFive(0.5),
  pointSevenFive(0.75),

  one(1.0),
  onePointTwoFive(1.25),
  onePointFive(1.5),
  onePointSevenFive(1.75),

  two(2.0),
  three(3.0),
  ;

  final double value;
  const PlaySpeed(this.value);
}
