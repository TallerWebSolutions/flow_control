hideAllComponents($('.nav-item'));

const stampsDiv = $('#nav-item-stamps');
stampsDiv.addClass('active');
$('#stamps').show();

const companyId = $("#company_id").val();
const projectId = $("#project_id").val();
const projectsIds = $("#projects_ids").val();
const targetName = $("#target_name").val();

$('.nav-item').on('click', function(event){
    hideAllComponents($('.nav-item'));
    const disabled = $(this).attr('disabled');

    const startDate = $('#charts_filter_start_date').val();
    const endDate = $('#charts_filter_end_date').val();

    const period = $('#charts_filter_period').val();

    if (disabled === 'disabled') {
        event.preventDefault();
    } else {
        disableTabs();

        if ($(this).attr('id') === 'nav-item-charts') {
            buildOperationalCharts(companyId, projectsIds, period, targetName, startDate, endDate, "");

        } else if ($(this).attr('id') === 'nav-item-strategic') {
            buildStrategicCharts(companyId, projectsIds, targetName);

        } else if ($(this).attr('id') === 'nav-item-demands') {
            $('#demands-tab').hide();
            getDemands(companyId, projectsIds);

        } else if ($(this).attr('id') === 'nav-item-demands-blocks') {
            $('#demands-blocks-tab').hide();
            getDemandBlocks(companyId, projectsIds, startDate, endDate);

        } else if ($(this).attr('id') === 'nav-item-flow-impacts') {
            $('#flow-impacts-tab').hide();
            getProjectFlowImpacts(companyId, projectId);

        } else if ($(this).attr('id') === 'nav-item-statistics') {
            const statsStartDate = '';
            const statsEndDate = '';
            const statsPeriod = 'month';
            const statsLeadtimeConfidence = '80';

            statisticsChartsRoute(companyId, projectsIds, statsPeriod, targetName, statsStartDate, statsEndDate, statsLeadtimeConfidence, '');

        } else {
            enableTabs();
            $($(this).data('container')).show();
        }

        $(this).addClass('active');
    }
});
