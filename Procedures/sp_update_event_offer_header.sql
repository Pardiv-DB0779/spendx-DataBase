-- PROCEDURE: public.sp_update_event_offer_header


CREATE OR REPLACE PROCEDURE public.sp_update_event_offer_header(
    IN p_offer_id integer,
    IN p_offer_no integer,
    IN p_offer_type_id integer)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_forecastCost numeric := 0;
    v_forecastSales numeric := 0;
    v_productTradeMargin numeric := 0;
    v_forecastTradeMargin numeric := 0;
    v_forecastTmPercent numeric := 0;
    v_forecastUnits integer := 0;
    v_incrementalUnits integer := 0;
    v_everydayUnits numeric := 0;
    v_spacePurchase numeric := 0;
    v_totalScanSupport numeric := 0;
    v_totalSupplierIncome numeric := 0;
    v_everydayPrice numeric := NULL;
    v_everydayPriceGst numeric := NULL;
    v_advertisedPrice numeric := NULL;
    v_advertisedPriceGst numeric := NULL;
    v_saveValue numeric := NULL;
    v_calcSavePercent numeric := NULL;
    v_calcSaveValue numeric := NULL;
BEGIN
    IF p_offer_type_id IN (18, 118) THEN
        -- 1. Aggregate from active SKUs in tEventOfferDetail
        SELECT
            ROUND(SUM(COALESCE(d."forecastCost", 0)), 2),
            ROUND(SUM(COALESCE(d."forecastSales", 0)), 2),
            ROUND(SUM(COALESCE(d."forecastTradeMargin$", 0)), 2),
            COALESCE(SUM(COALESCE(d."categoryforecast", 0)), 0)::int,
            COALESCE(SUM(COALESCE(d."incrementalForecast", 0)), 0)::int,
            ROUND(SUM(COALESCE(d."everydayUnits", 0)), 2),
            ROUND(SUM(COALESCE(d."scanSupport$", 0)), 2)
        INTO
            v_forecastCost,
            v_forecastSales,
            v_productTradeMargin,
            v_forecastUnits,
            v_incrementalUnits,
            v_everydayUnits,
            v_totalScanSupport
        FROM public."teventofferdetail" d
        WHERE d."offerId" = p_offer_id
          AND d."offerNo" = p_offer_no
          AND (d."isSkuActive" = TRUE OR d."isSkuActive" IS NULL);

        -- 2. Retrieve Space Purchase from header
        SELECT COALESCE("spacePurchase", 0)
        INTO v_spacePurchase
        FROM public."tEventOffer"
        WHERE "offerId" = p_offer_id
          AND "offerNumber" = p_offer_no;

        -- 3. Total Supplier Income (BRD Item 2: SpacePurchase + TotalScanSupport)
        v_totalSupplierIncome := v_spacePurchase + COALESCE(v_totalScanSupport, 0);

        -- 4. Forecast Trade Margin $ (BRD Item 2: Product Margin + Total Supplier Income)
        v_forecastTradeMargin := v_productTradeMargin + v_totalSupplierIncome;

        -- 5. Calculate trade margin percentage
        IF v_forecastSales > 0 THEN
            v_forecastTmPercent := ROUND((v_forecastTradeMargin / v_forecastSales) * 100.0, 2);
        ELSE
            v_forecastTmPercent := 0;
        END IF;

        -- 6. Retrieve representative item pricing
        SELECT 
            d."everydayPrice",
            d."everydayPriceGst",
            d."advertisedPrice",
            d."advertisedPriceGst",
            d."calculatedSaveValue",
            d."calculatedSavePercentage",
            d."calculatedSaveValue"
        INTO
            v_everydayPrice,
            v_everydayPriceGst,
            v_advertisedPrice,
            v_advertisedPriceGst,
            v_saveValue,
            v_calcSavePercent,
            v_calcSaveValue
        FROM public."teventofferdetail" d
        WHERE d."offerId" = p_offer_id
          AND d."offerNo" = p_offer_no
          AND (d."isSkuActive" = TRUE OR d."isSkuActive" IS NULL)
          AND d."advertisedPrice" IS NOT NULL
        LIMIT 1;

        -- 7. Update Header Rollups in tEventOffer
        UPDATE public."tEventOffer"
        SET
            "forecastCost"          = v_forecastCost,
            "forecastSales"         = v_forecastSales,
            "forecastTradeMargin"   = v_forecastTradeMargin,
            "forecastTradeMargin$"  = v_forecastTradeMargin,
            "forecastTmPercent"     = v_forecastTmPercent,
            "forecastTradeMargin%"  = v_forecastTmPercent,
            "forecastUnits"         = v_forecastUnits,
            "incrementalUnits"      = v_incrementalUnits,
            "everydayUnits"         = v_everydayUnits,
            "totalScanSupport$"     = v_totalScanSupport,
            "totalSupplierIncome"   = v_totalSupplierIncome,
            "everydayPrice"         = COALESCE(v_everydayPrice, "everydayPrice"),
            "everydayPriceGst"      = COALESCE(v_everydayPriceGst, "everydayPriceGst"),
            "advertisedPrice"       = COALESCE(v_advertisedPrice, "advertisedPrice"),
            "advertisedPriceGst"    = COALESCE(v_advertisedPriceGst, "advertisedPriceGst"),
            "saveValue"             = COALESCE(v_saveValue, "saveValue"),
            "calculatedSavePercent" = COALESCE(v_calcSavePercent, "calculatedSavePercent"),
            "calculatedSaveValue"   = COALESCE(v_calcSaveValue, "calculatedSaveValue"),
            "updatedAt"             = CURRENT_TIMESTAMP
        WHERE "offerId" = p_offer_id
          AND "offerNumber" = p_offer_no;
    END IF;
END;
$BODY$;
