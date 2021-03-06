function buildStatusReportCurrentCharts() {
    const burnupHoursPerWeek = $('#burnup-hours-per-week');
    buildBurnupChart(burnupHoursPerWeek);

    const statusReportDeliveredDiv = $('#status-report-delivered-column');
    buildColumnChart(statusReportDeliveredDiv);

    const statusReportDeadlineDiv = $('#status-report-deadline-bar');
    buildBarChart(statusReportDeadlineDiv);

    const statusReportCFDDownstreamDiv = $('#cfd-downstream-area');
    buildAreaChart(statusReportCFDDownstreamDiv);

    const statusReportCFDUpstreamDiv = $('#cfd-upstream-area');
    buildAreaChart(statusReportCFDUpstreamDiv);

    const throughputByProject = $('#throughput-by-project');
    buildColumnChart(throughputByProject);
}
