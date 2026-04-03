// ignore_for_file: constant_identifier_names

enum LiveContributionRankType {
  online_rank('在线榜', 'contribution_rank'),
  daily_rank('日榜', 'today_rank'),
  weekly_rank('周榜', 'current_week_rank'),
  monthly_rank('月榜', 'current_month_rank'),
  ;

  final String title;
  final String sw1tch;
  const LiveContributionRankType(this.title, this.sw1tch);
}
