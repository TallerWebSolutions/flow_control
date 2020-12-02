$("#general-loader").hide();

$('#team-dashboard-tab').addClass('active');

$('#team-dashboard-page-one').addClass('active');
$('#team-dashboard-page-two').removeClass('active');
$('#team-dashboard-page-three').removeClass('active');
$('#team-dashboard-page-four').removeClass('active');

$("#team-dashboard-container-page-one").show();
$("#team-dashboard-container-page-two").hide();
$("#team-dashboard-container-page-three").hide();
$("#team-dashboard-container-page-four").hide();

$('#page-buttons').show();

startCharts();
bindDashboardSelectors();

$('.filter-button').on('click', function() {
    filterTeamDemands()
});
