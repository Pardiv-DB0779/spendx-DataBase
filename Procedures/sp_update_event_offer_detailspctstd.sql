-- PROCEDURE: public.sp_update_event_offer_detailspctstd
-- Wrapper / alias procedure redirecting SpendX batch execution to sp_update_event_offer_details_spendx

CREATE OR REPLACE PROCEDURE public.sp_update_event_offer_detailspctstd()
LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
    CALL public.sp_update_event_offer_details_spendx();
END;
$BODY$;
