$(function() { // DOM ready
    /* Show a violation */
    $('#section').on('click', '[href*="#modalViolation"]', function(event) {
        var modal = $('#modalViolation');
        var url = $(this).attr('href');
        var section = $('#section');
        var loader = section.prev('.loader');
        loader.show();
        section.fadeTo('fast', 0.5);
        modal.empty();
        $.ajax(url)
            .always(function(){
                loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
            })
            .done(function(data) {
                modal.append(data);
                $('.switch').bootstrapSwitch();
                $('.chzn-select').chosen();
                $('.chzn-deselect').chosen({allow_single_deselect: true});
                modal.modal('show');
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                $("body,html").animate({scrollTop:0}, 'fast');
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Create a violation */
    $('#section').on('click', '#createViolation', function(event) {
        var modal = $('#modalViolation');
        var url = $(this).attr('href');
        var section = $('#section');
        var loader = section.prev('.loader');
        loader.show();
        section.fadeTo('fast', 0.5);
        modal.empty();
        $.ajax(url)
            .always(function(){
                loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
            })
            .done(function(data) {
                modal.append(data);
                $('.switch').bootstrapSwitch();
                $('.chzn-select').chosen();
                $('.chzn-deselect').chosen({allow_single_deselect: true});
                modal.modal('show');
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Delete a violation */
    $('#section').on('click', '[href*="#deleteViolation"]', function(event) {
        if ($(this).hasClass('disabled'))
            return false;
        var url = $(this).attr('href');
        var row = $(this).closest('tr');
        var cells = row.find('td');
        var name = $(cells[1]).text();
        if (!name) name = $(cells[0]).text();
        var modal = $('#deleteViolation');
        var confirm_link = modal.find('a.btn-primary').first();
        modal.find('h3 span').html(name);
        modal.modal('show');
        confirm_link.off('click');
        confirm_link.click(function() {
            $.ajax(url)
                .always(function() {
                    modal.modal('hide');
                })
                .done(function(data) {
                    row.remove();
                    var table = $('#section table');
                    if (table.find('tbody tr').length == 0) {
                        // No more violations
                        table.remove();
                        $('#noViolation').removeClass('hidden');
                    }
                })
                .fail(function(jqXHR) {
                    var status_msg = getStatusMsg(jqXHR);
                    showError($('#section h2'), status_msg);
                });
        });

        return false;
    });

    /* Modal Editor: add a trigger */
    $('body').on('click', '[href="#addTrigger"]', function(event) {
        var id = $(this).prev().val();
        var type = $(this).prev().prev().val();
        var name = type + "::" + id;
        var select = $('#trigger');
        var last = true;
        select.find('option').each(function() {
            if ($(this).val() > name) {
                $('<option value="' + name + '" selected="selected">' + name + '</option>').insertBefore(this);
                last = false;
                return false;
            }
        });
        if (last)
            select.append('<option value="' + name + '" selected="selected">' + name + '</option>');
        select.trigger("liszt:updated");
    });

    /* Modal Editor: save a violation */
    $('body').on('submit', 'form[name="violation"]', function(event) {
        var form = $(this),
        modal = $('#modalViolation'),
        modal_body = modal.find('.modal-body'),
        valid = isFormValid(form);

        if (valid) {
            resetAlert(modal_body);
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).done(function() {
                modal.modal('hide');
                modal.on('hidden', function() {
                    // Refresh the section
                    $(window).hashchange();
                });
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), status_msg);
            });
        }

        return false;
    });

    /* Preview a violation's remediation page */
    $('#section').on('click', '[href*="#previewPage"]', function(event) {
        if ($(this).hasClass('disabled'))
            return false;
        var modal = $('#modalViolation');
        var url = $(this).attr('href');
        modal.empty();
        modal.modal('show');
        $.ajax(url)
            .done(function(data) {
                modal.append(data);
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

        return false;
    });
});