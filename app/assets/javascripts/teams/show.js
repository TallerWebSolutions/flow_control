$("#general-loader").hide();

const hoursGauge = $('#hours-gauge');
buildGaugeChart(hoursGauge);

accordionBehaviour();

$('#search_charts').on('click', function() {
    const companyId = $('#company_id').val();
    const teamId = $('#team_id').val();
    const projects_ids = $("#projects_ids").val();
    const startDate = $('#charts_filter_start_date').val();
    const endDate = $('#charts_filter_end_date').val();
    const period = $('#charts_filter_period').val();
    const targetName = $('#target_name').val();

    buildOperationalCharts(companyId, projects_ids, period, targetName, startDate, endDate, teamId)
});
