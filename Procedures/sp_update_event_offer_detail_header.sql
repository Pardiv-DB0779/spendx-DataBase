-- PROCEDURE: public.sp_update_event_offer_detail_header


CREATE OR REPLACE PROCEDURE public.sp_update_event_offer_detail_header(
    IN p_offer_id integer,
    IN p_offer_no integer,
    IN p_offer_type_id integer,
    IN p_save_percent numeric DEFAULT NULL,
    IN p_incremental_percent numeric DEFAULT NULL,
    IN p_space_purchase numeric DEFAULT NULL,
    IN p_advertised_price_gst numeric DEFAULT NULL,
    IN p_total_multibuy_price numeric DEFAULT NULL,
    IN p_required_qty integer DEFAULT NULL,
    IN p_spend1 numeric DEFAULT NULL,
    IN p_save_pct1 numeric DEFAULT NULL,
    IN p_spend2 numeric DEFAULT NULL,
    IN p_save_pct2 numeric DEFAULT NULL,
    IN p_spend3 numeric DEFAULT NULL,
    IN p_save_pct3 numeric DEFAULT NULL)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_country text := 'AU';
    v_duration_days integer := 0;
    v_max_discount numeric := 0;
BEGIN
    IF p_offer_type_id IN (18, 118) THEN
        -- 1. Fetch Event and Header metadata
        SELECT
            COALESCE(eh."country", eoh."country", 'AU'),
            COALESCE((eh."endDate" - eh."startDate") + 1, 0)
        INTO
            v_country,
            v_duration_days
        FROM public."tEventOffer" eoh
        LEFT JOIN public."tEvent" eh ON eh."eventId" = eoh."eventId"
        WHERE eoh."offerId" = p_offer_id
          AND eoh."offerNumber" = p_offer_no
        LIMIT 1;

        -- 2. Update Header Thresholds & Configuration for SpendX
        UPDATE public."tEventOffer"
        SET
            "spend1"                = COALESCE(p_spend1, "spend1"),
            "savePct1"              = COALESCE(p_save_pct1, p_save_percent, "savePct1"),
            "spend2"                = COALESCE(p_spend2, "spend2"),
            "savePct2"              = COALESCE(p_save_pct2, "savePct2"),
            "spend3"                = COALESCE(p_spend3, "spend3"),
            "savePct3"              = COALESCE(p_save_pct3, "savePct3"),
            "savePercent"           = COALESCE(p_save_pct1, p_save_percent, "savePercent"),
            "incrementalPercentage" = COALESCE(p_incremental_percent, "incrementalPercentage", 0),
            "spacePurchase"         = COALESCE(p_space_purchase, "spacePurchase", 0),
            "updatedAt"             = CURRENT_TIMESTAMP
        WHERE "offerId" = p_offer_id
          AND "offerNumber" = p_offer_no;

        -- 3. Calculate max nominal discount percentage across all 3 tiers (BRD Item 1)
        SELECT GREATEST(
            COALESCE("savePct1", 0),
            COALESCE("savePct2", 0),
            COALESCE("savePct3", 0),
            0
        )
        INTO v_max_discount
        FROM public."tEventOffer"
        WHERE "offerId" = p_offer_id
          AND "offerNumber" = p_offer_no;

        -- 4. Update line items in tEventOfferDetail using CTEs
        WITH calc_base AS (
            SELECT 
                d."offerId",
                d."offerNo",
                d."sku",
                -- Base Everyday Units
                CASE
                    WHEN COALESCE(d."everydayUnits", 0) > 0 THEN d."everydayUnits"
                    ELSE ROUND((COALESCE(p."averageMonthlySales", 0.0) / 30.0) * v_duration_days, 2)
                END AS base_everyday_units,
                -- Unit cost & price
                COALESCE(d."nationalAverageCost", d."vendorCostPerEach", p."nationalAverageCost", 0) AS unit_cost,
                COALESCE(d."everydayPrice", p."everydayPrice", 0) AS unit_price,
                COALESCE(d."everydayPriceGst", p."everydayPriceGst", 0) AS unit_price_gst,
                -- Advertised Price based on max nominal discount % (BRD Item 1)
                CASE 
                    WHEN v_max_discount > 0 THEN ROUND(COALESCE(d."everydayPrice", p."everydayPrice", 0) * (1.0 - (v_max_discount / 100.0)), 2)
                    ELSE COALESCE(d."everydayPrice", p."everydayPrice", 0)
                END AS adv_price,
                CASE 
                    WHEN v_max_discount > 0 THEN ROUND(COALESCE(d."everydayPriceGst", p."everydayPriceGst", 0) * (1.0 - (v_max_discount / 100.0)), 2)
                    ELSE COALESCE(d."everydayPriceGst", p."everydayPriceGst", 0)
                END AS adv_price_gst,
                -- Latest SOH from products
                COALESCE(p."stockOnHandStore", d."stockOnHandStore", 0) AS soh_store,
                COALESCE(p."stockOnHandDc", d."stockOnHandDc", 0) AS soh_dc,
                COALESCE(p_incremental_percent, o."incrementalPercentage", 0) AS inc_pct,
                COALESCE(d."scanSupportValue", 0) AS scan_support_val,
                d."isCategoryForecastLocked",
                d."incrementalForecast" AS locked_inc_forecast,
                d."categoryforecast" AS locked_cat_forecast
            FROM public."teventofferdetail" d
            JOIN public."tEventOffer" o 
              ON o."offerId" = d."offerId" AND o."offerNumber" = d."offerNo"
            LEFT JOIN public."tproducts" p 
              ON p."sku" = d."sku" AND p."country" = v_country
            WHERE d."offerId" = p_offer_id
              AND d."offerNo" = p_offer_no
              AND (d."isSkuActive" = TRUE OR d."isSkuActive" IS NULL)
        ),
        forecast_calc AS (
            SELECT
                cb."offerId",
                cb."offerNo",
                cb."sku",
                cb.base_everyday_units,
                cb.unit_cost,
                cb.unit_price,
                cb.unit_price_gst,
                cb.adv_price,
                cb.adv_price_gst,
                cb.soh_store,
                cb.soh_dc,
                cb.scan_support_val,
                -- Incremental forecast
                CASE 
                    WHEN cb."isCategoryForecastLocked" = TRUE THEN cb.locked_inc_forecast
                    ELSE ROUND(cb.base_everyday_units * (cb.inc_pct / 100.0))::int
                END AS calc_inc_forecast,
                -- Category forecast
                CASE 
                    WHEN cb."isCategoryForecastLocked" = TRUE THEN cb.locked_cat_forecast
                    ELSE (ROUND(cb.base_everyday_units) + ROUND(cb.base_everyday_units * (cb.inc_pct / 100.0)))::int
                END AS calc_cat_forecast
            FROM calc_base cb
        )
        UPDATE public."teventofferdetail" d
        SET
            "everydayUnits"            = fc.base_everyday_units,
            "incrementalForecast"      = fc.calc_inc_forecast,
            "categoryforecast"         = fc.calc_cat_forecast,
            "forecastUnits"            = fc.calc_cat_forecast,
            "advertisedPrice"          = fc.adv_price,
            "advertisedPriceGst"       = fc.adv_price_gst,
            "calculatedSavePercentage" = v_max_discount,
            "calculatedSaveValue"      = ROUND(fc.unit_price - fc.adv_price, 2),
            "extendedAdvertisedPrice"  = ROUND(fc.calc_cat_forecast * fc.adv_price, 2),
            "scanSupport$"             = ROUND(fc.scan_support_val * fc.calc_cat_forecast, 2),
            "forecastCost"             = ROUND(fc.calc_cat_forecast * fc.unit_cost, 2),
            "forecastSales"            = ROUND(fc.calc_cat_forecast * fc.adv_price, 2),
            "forecastTradeMargin$"     = ROUND((fc.calc_cat_forecast * fc.adv_price) - (fc.calc_cat_forecast * fc.unit_cost), 2),
            "forecastTradeMargin%"     = CASE
                                            WHEN (fc.calc_cat_forecast * fc.adv_price) > 0 THEN 
                                                ROUND((((fc.calc_cat_forecast * fc.adv_price) - (fc.calc_cat_forecast * fc.unit_cost)) / (fc.calc_cat_forecast * fc.adv_price)) * 100.0, 2)
                                            ELSE 0
                                         END,
            "stockOnHandStore"         = fc.soh_store,
            "stockOnHandDc"            = fc.soh_dc
        FROM forecast_calc fc
        WHERE d."offerId" = fc."offerId"
          AND d."offerNo" = fc."offerNo"
          AND d."sku" = fc."sku";

        -- 5. Roll up to header
        CALL public.sp_update_event_offer_header(p_offer_id, p_offer_no, p_offer_type_id);
    END IF;
END;
$BODY$;
