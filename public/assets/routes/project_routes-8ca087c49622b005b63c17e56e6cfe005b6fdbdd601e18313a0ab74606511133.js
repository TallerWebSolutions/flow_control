function searchDemandsByFlowStatus(companyId, projectId, flatDemands, groupedByMonth, groupedByCustomer, notStarted, committed, delivered) {
    jQuery.ajax({
        url: "/companies/" + companyId + '/projects/' + projectId + "/search_demands_by_flow_status" + ".js",
        type: "GET",
        data: '&flat_demands=' + flatDemands + '&grouped_by_month=' + groupedByMonth + '&grouped_by_customer=' + groupedByCustomer + '&not_started=' + notStarted + '&wip=' + committed + '&delivered=' + delivered
    });
}
;
