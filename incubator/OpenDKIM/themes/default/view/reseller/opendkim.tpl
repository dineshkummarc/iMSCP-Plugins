<!-- BDP: select_list -->
<script>
    $(function () {
        $("#activate_customer").on('submit', function($e) {
            if($(this).find("select").val() == -1)
                $e.preventDefault();
        });
    });
</script>
<form name="activate_customer" id="activate_customer" action="opendkim.php" method="post">
    <label>
        <select name="admin_id">
            <option value="-1">{TR_SELECT_NAME}</option>
            <!-- BDP: select_item -->
            <option value="{SELECT_VALUE}">{SELECT_NAME}</option>
            <!-- EDP: select_item -->
        </select>
    </label>
    <div class="buttons" style="display:inline">
        <input type="hidden" name="action" value="activate">
        <input name="submit" type="submit" value="{TR_ACTIVATE_ACTION}">
    </div>
</form>
<!-- EDP: select_list -->
<!-- BDP: customer_list -->
<script>
    $(function () {
        $(".link_as_button").on('click', function () {
            if($.isFunction($.imscp.confirmOnclick)) {
                return $.imscp.confirmOnclick(this, "{DEACTIVATE_DOMAIN_ALERT}");
            }

            return confirm("{DEACTIVATE_DOMAIN_ALERT}");
        });
    });
</script>
<!-- BDP: customer_item -->
<table>
    <thead>
    <tr>
        <th style="width:15%">{TR_STATUS}</th>
        <th style="width:10%">{TR_DOMAIN_NAME}</th>
        <th style="width:20%">{TR_DNS_NAME}</th>
        <th style="width:55%">{TR_DOMAIN_KEY}</th>
    </tr>
    </thead>
    <tfoot>
    <tr>
        <td colspan="4">{TR_CUSTOMER}</td>
    </tr>
    </tfoot>
    <tbody>
    <!-- BDP: key_item -->
    <tr>
        <td><div class="icon i_{STATUS_ICON}">{KEY_STATUS}<div></td>
        <td><label for="keyid_{OPENDKIM_ID}">{DOMAIN_NAME}</label></td>
        <td>{DNS_NAME}</td>
        <td><textarea id="keyid_{OPENDKIM_ID}" name="opendkim_key" style="background: #fff none;width:95%;height:100px;resize:none;" readonly>{DOMAIN_KEY}</textarea></td>
    </tr>
    <!-- EDP: key_item -->
    </tbody>
</table>
<div class="buttons">
    <a class="link_as_button" href="opendkim.php?action=deactivate&admin_id={CUSTOMER_ID}">{TR_DEACTIVATE}</a>
</div>
<br/>
<!-- EDP: customer_item -->
<div class="paginator">
    <!-- BDP: scroll_prev -->
    <a class="icon i_prev" href="opendkim.php?psi={PREV_PSI}" title="{TR_PREVIOUS}">{TR_PREVIOUS}</a>
    <!-- EDP: scroll_prev -->
    <!-- BDP: scroll_prev_gray -->
    <span class="icon i_prev_gray"></span>
    <!-- EDP: scroll_prev_gray -->
    <!-- BDP: scroll_next_gray -->
    <span class="icon i_next_gray"></span>
    <!-- EDP: scroll_next_gray -->
    <!-- BDP: scroll_next -->
    <a class="icon i_next" href="opendkim.php?psi={NEXT_PSI}" title="{TR_NEXT}">{TR_NEXT}</a>
    <!-- EDP: scroll_next -->
</div>
<!-- EDP: customer_list -->
