hideAllComponents();

const stampsDiv = $('#nav-item-stamps');
stampsDiv.addClass('active');
$('#stamps').show();

const companyId = $("#company_id").val();
const projectId = $("#project_id").val();
const projectsIds = $("#projects_ids").val();
const targetName = $("#target_name").val();

$('.nav-item').on('click', function(event){
    hideAllComponents();
    const disabled = $(this).attr('disabled');

    const startDate = $('#operational_charts_start_date').val();
    const endDate = $('#operational_charts_end_date').val();

    const period = $('#operational_charts_period').val();

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

function hideAllComponents() {
    $('.tab-container').hide();
    $('.nav-item').removeClass('active');
}
