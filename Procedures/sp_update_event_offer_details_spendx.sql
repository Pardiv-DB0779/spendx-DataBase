-- PROCEDURE: public.sp_update_event_offer_details_spendx


CREATE OR REPLACE PROCEDURE public.sp_update_event_offer_details_spendx()
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT DISTINCT
            o."offerId",
            o."offerNumber",
            o."offerTypeId",
            o."savePercent",
            o."incrementalPercentage",
            o."spacePurchase",
            o."spend1",
            o."savePct1",
            o."spend2",
            o."savePct2",
            o."spend3",
            o."savePct3",
            COALESCE(e."country", o."country", 'AU') AS resolved_country
        FROM public."tEventOffer" o
        LEFT JOIN public."tEvent" e ON e."eventId" = o."eventId"
        WHERE o."offerTypeId" IN (18, 118)
          AND (o."isOfferActive" = TRUE OR o."status" IN ('Open', 'Draft', 'Locked'))
    LOOP
        -- 1. Sync latest stock on hand & prices from tproducts with correct country join
        UPDATE public."teventofferdetail" d
        SET
            "stockOnHandStore"   = COALESCE(p."stockOnHandStore", d."stockOnHandStore", 0),
            "stockOnHandDc"      = COALESCE(p."stockOnHandDc", d."stockOnHandDc", 0),
            "vendorCostPerEach"  = COALESCE(p."vendorCostPerEach", d."vendorCostPerEach"),
            "nationalAverageCost"= COALESCE(p."nationalAvgCost", d."nationalAverageCost"),
            "everydayPrice"      = COALESCE(p."everydayPrice", d."everydayPrice"),
            "everydayPriceGst"   = COALESCE(p."everydayPriceGst", d."everydayPriceGst")
        FROM public."tproducts" p
        WHERE p."sku" = d."sku" 
          AND p."country" = r.resolved_country
          AND d."offerId" = r."offerId"
          AND d."offerNo" = r."offerNumber"
          AND d."isSkuActive" = TRUE;

        -- 2. Recalculate detail lines and roll up header totals
        CALL public.sp_update_event_offer_detail_header(
            r."offerId",
            r."offerNumber",
            r."offerTypeId",
            r."savePercent",
            r."incrementalPercentage",
            r."spacePurchase",
            NULL, -- p_advertised_price_gst
            NULL, -- p_total_multibuy_price
            NULL, -- p_required_qty
            r."spend1",
            r."savePct1",
            r."spend2",
            r."savePct2",
            r."spend3",
            r."savePct3"
        );
    END LOOP;
END;
$BODY$;
