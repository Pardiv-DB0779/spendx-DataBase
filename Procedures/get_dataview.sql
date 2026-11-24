-- FUNCTION: public.get_dataview


DROP FUNCTION IF EXISTS public.get_dataview(integer, integer, text[], text[], text[], text[], boolean, boolean, integer, integer);
DROP FUNCTION IF EXISTS public.get_dataview(integer, integer, text[], text[], text[], text[], boolean, boolean, boolean, boolean, integer, integer);
DROP FUNCTION IF EXISTS public.get_dataview(integer, integer, text[], text[], text[], text[], boolean, boolean, boolean, boolean, integer, integer, boolean);

CREATE OR REPLACE FUNCTION public.get_dataview(
    p_offer_id integer DEFAULT 1,
    p_offer_no integer DEFAULT 1,
    p_skus text[] DEFAULT NULL::text[],
    p_part_numbers text[] DEFAULT NULL::text[],
    p_brands text[] DEFAULT NULL::text[],
    p_part_descriptions text[] DEFAULT NULL::text[],
    p_sort_advpricegst_desc boolean DEFAULT NULL::boolean,
    p_sort_edpricegst_desc boolean DEFAULT NULL::boolean,
    p_sort_edunits_desc boolean DEFAULT NULL::boolean,
    p_sort_catfcst_desc boolean DEFAULT NULL::boolean,
    p_page_number integer DEFAULT 1,
    p_page_size integer DEFAULT 100,
    p_sort_edprice_desc boolean DEFAULT NULL::boolean)
RETURNS TABLE(
    sku text,
    part_number text,
    brand text,
    description text,
    frompriceind boolean,
    displayind boolean,
    clearance text,
    showroom text,
    advpricegst numeric,
    edprice numeric,
    edpricegst numeric,
    futureedprice numeric,
    futureedeffectivedate date,
    calcsavepercent numeric,
    calcsavevalue numeric,
    lecost numeric,
    natavgcost numeric,
    catfcst integer,
    incrfcst integer,
    fcstcost numeric,
    fcstsales numeric,
    fcsttmvalue numeric,
    fcsttmpercent numeric,
    edunits numeric,
    scansupportvalue numeric,
    scansupportpercent numeric,
    sohstore integer,
    sohdc integer,
    grp0qty integer,
    grp1qty integer,
    grp2qty integer,
    grp3qty integer,
    grp4qty integer,
    grp5qty integer,
    totaltieup integer,
    tieuppercentfcst numeric,
    tieupcost numeric,
    supplierid text,
    suppliername text,
    ic2 text,
    ic3 text,
    ic4 text,
    comofferic1 text,
    incrementaltmdollar numeric,
    incrementalsalesdollar numeric,
    edcost numeric,
    edunittmdollar numeric,
    advunittmdollar numeric,
    advsalesdollar numeric,
    edsalesdollar numeric,
    spend1 numeric,
    savepct1 numeric,
    spend2 numeric,
    savepct2 numeric,
    spend3 numeric,
    savepct3 numeric,
    istiered boolean,
    advpriceexgst numeric,
    iscatfcstlocked boolean,
    total_count integer,
    isskuedited boolean,
    isskuactive boolean,
    isfrompriceoverriden boolean
)
LANGUAGE plpgsql
STABLE
AS $BODY$
DECLARE
    v_sql TEXT;
    v_tbl TEXT;
    v_prod_tbl TEXT;
    v_hdr_tbl TEXT;
    v_filter_clauses TEXT[] := ARRAY[]::TEXT[];
    v_where TEXT := '';
    v_order TEXT := '';

    v_page_num INT := GREATEST(1, COALESCE(p_page_number, 1));
    v_page_sz INT := GREATEST(1, COALESCE(p_page_size, 100));
    v_offset INT := (v_page_num - 1) * v_page_sz;
BEGIN
    -- 1. Dynamic Table Resolution across environments
    IF to_regclass('public."tEventOfferDetail"') IS NOT NULL THEN
        v_tbl := 'public."tEventOfferDetail"';
    ELSE
        v_tbl := 'public."teventofferdetail"';
    END IF;

    IF to_regclass('public."tProducts"') IS NOT NULL THEN
        v_prod_tbl := 'public."tProducts"';
    ELSE
        v_prod_tbl := 'public."tproducts"';
    END IF;

    IF to_regclass('public."tEventOffer"') IS NOT NULL THEN
        v_hdr_tbl := 'public."tEventOffer"';
    ELSE
        v_hdr_tbl := 'public."teventoffer"';
    END IF;

    -- 2. Build Filter Conditions (Clean grouping with cardinality check)
    IF p_skus IS NOT NULL AND cardinality(p_skus) > 0 THEN
        v_filter_clauses := array_append(
            v_filter_clauses,
            '(' ||
            array_to_string(
                ARRAY(
                    SELECT format('d."sku" ILIKE %L', s || '%')
                    FROM unnest(p_skus) AS s
                    WHERE s IS NOT NULL
                ),
                ' OR '
            ) ||
            ')'
        );
    END IF;

    IF p_part_numbers IS NOT NULL AND cardinality(p_part_numbers) > 0 THEN
        v_filter_clauses := array_append(
            v_filter_clauses,
            '(' ||
            array_to_string(
                ARRAY(
                    SELECT format('d."partNo" ILIKE %L', s || '%')
                    FROM unnest(p_part_numbers) AS s
                    WHERE s IS NOT NULL
                ),
                ' OR '
            ) ||
            ')'
        );
    END IF;

    IF p_brands IS NOT NULL AND cardinality(p_brands) > 0 THEN
        v_filter_clauses := array_append(
            v_filter_clauses,
            '(' ||
            array_to_string(
                ARRAY(
                    SELECT format('COALESCE(d."brand", p."brand", '''') ILIKE %L', s || '%')
                    FROM unnest(p_brands) AS s
                    WHERE s IS NOT NULL
                ),
                ' OR '
            ) ||
            ')'
        );
    END IF;

    IF p_part_descriptions IS NOT NULL AND cardinality(p_part_descriptions) > 0 THEN
        v_filter_clauses := array_append(
            v_filter_clauses,
            '(' ||
            array_to_string(
                ARRAY(
                    SELECT format('COALESCE(d."description", p."description", '''') ILIKE %L', '%' || s || '%')
                    FROM unnest(p_part_descriptions) AS s
                    WHERE s IS NOT NULL
                ),
                ' OR '
            ) ||
            ')'
        );
    END IF;

    IF cardinality(v_filter_clauses) > 0 THEN
        v_where := ' AND ' || array_to_string(v_filter_clauses, ' AND ');
    END IF;

    -- 3. Sorting with outer-query alias 'f'
    IF p_sort_advpricegst_desc IS NOT NULL THEN
        v_order := ' ORDER BY f.advpricegst ' || CASE WHEN p_sort_advpricegst_desc THEN 'DESC NULLS LAST' ELSE 'ASC NULLS FIRST' END || ', f.sku ASC';
    ELSIF p_sort_edpricegst_desc IS NOT NULL THEN
        v_order := ' ORDER BY f.edpricegst ' || CASE WHEN p_sort_edpricegst_desc THEN 'DESC NULLS LAST' ELSE 'ASC NULLS FIRST' END || ', f.sku ASC';
    ELSIF p_sort_edunits_desc IS NOT NULL THEN
        v_order := ' ORDER BY f.edunits ' || CASE WHEN p_sort_edunits_desc THEN 'DESC NULLS LAST' ELSE 'ASC NULLS FIRST' END || ', f.sku ASC';
    ELSIF p_sort_catfcst_desc IS NOT NULL THEN
        v_order := ' ORDER BY f.catfcst ' || CASE WHEN p_sort_catfcst_desc THEN 'DESC NULLS LAST' ELSE 'ASC NULLS FIRST' END || ', f.sku ASC';
    ELSIF p_sort_edprice_desc IS NOT NULL THEN
        v_order := ' ORDER BY f.edprice ' || CASE WHEN p_sort_edprice_desc THEN 'DESC NULLS LAST' ELSE 'ASC NULLS FIRST' END || ', f.sku ASC';
    ELSE
        v_order := ' ORDER BY f.sku ASC';
    END IF;

    -- 4. Main Query: Paged SQL 
    v_sql := '
        WITH filtered AS (
            SELECT
                d."sku"::text AS sku,
                COALESCE(d."partNo", d."sku")::text AS part_number,
                COALESCE(d."brand", p."brand", '''')::text AS brand,
                COALESCE(d."description", p."description", '''')::text AS description,
                COALESCE(d."fromPriceIndicator", FALSE) AS frompriceind,
                COALESCE(d."displayIndicator", TRUE) AS displayind,
                d."clearanceIndicator"::text AS clearance,
                d."showroomIndicator"::text AS showroom,
                COALESCE(d."advertisedPriceGst", 0)::numeric AS advpricegst,
                COALESCE(d."everydayPrice", 0)::numeric AS edprice,
                COALESCE(d."everydayPriceGst", 0)::numeric AS edpricegst,
                d."futureEdPrice"::numeric AS futureedprice,
                d."futureEdEffectiveDate"::date AS futureedeffectivedate,

                COALESCE(
                    d."calculatedSavePercentage",
                    CASE
                        WHEN COALESCE(d."everydayPriceGst", 0) > 0
                        THEN ROUND(((d."everydayPriceGst" - COALESCE(d."advertisedPriceGst", 0)) / d."everydayPriceGst") * 100, 2)
                        ELSE 0
                    END
                )::numeric AS calcsavepercent,

                COALESCE(
                    d."calculatedSaveValue",
                    ROUND(COALESCE(d."everydayPriceGst", 0) - COALESCE(d."advertisedPriceGst", 0), 2)
                )::numeric AS calcsavevalue,

                COALESCE(d."leCost", d."LatestEffectiveCost", 0)::numeric AS lecost,
                COALESCE(d."nationalAverageCost", 0)::numeric AS natavgcost,
                COALESCE(d."categoryforecast", 0)::integer AS catfcst,

                -- Dynamic fallback: categoryforecast - everydayUnits if incrementalForecast is 0
                COALESCE(
                    NULLIF(d."incrementalForecast", 0),
                    (COALESCE(d."categoryforecast", 0) - COALESCE(d."everydayUnits", 0)::integer)
                )::integer AS incrfcst,

                COALESCE(d."forecastCost", 0)::numeric AS fcstcost,
                COALESCE(d."forecastSales", 0)::numeric AS fcstsales,
                COALESCE(d."forecastTradeMargin$", 0)::numeric AS fcsttmvalue,
                COALESCE(d."forecastTradeMargin%", 0)::numeric AS fcsttmpercent,
                COALESCE(d."everydayUnits", 0)::numeric AS edunits,
                COALESCE(d."scanSupport$", d."scanSupportValue", 0)::numeric AS scansupportvalue,
                COALESCE(d."scanSupport%", d."scanSupportPercent", 0)::numeric AS scansupportpercent,
                COALESCE(d."stockOnHandStore", 0)::integer AS sohstore,
                COALESCE(d."stockOnHandDc", 0)::integer AS sohdc,
                COALESCE(d."group0Quantity", d."G0", 0)::integer AS grp0qty,
                COALESCE(d."group1Quantity", d."G1", 0)::integer AS grp1qty,
                COALESCE(d."group2Quantity", d."G2", 0)::integer AS grp2qty,
                COALESCE(d."group3Quantity", d."G3", 0)::integer AS grp3qty,
                COALESCE(d."group4Quantity", d."G4", 0)::integer AS grp4qty,
                COALESCE(d."group5Quantity", d."G5", 0)::integer AS grp5qty,
                COALESCE(d."totalTieUp", 0)::integer AS totaltieup,

                CASE
                    WHEN COALESCE(d."categoryforecast", 0) > 0
                    THEN ROUND(COALESCE(d."totalTieUp", 0)::numeric / d."categoryforecast", 2)
                    ELSE 0
                END::numeric AS tieuppercentfcst,

                COALESCE(d."tieUpCost", 0)::numeric AS tieupcost,
                COALESCE(p."supplierId", '''')::text AS supplierid,
                COALESCE(p."supplierName", '''')::text AS suppliername,
                COALESCE(d."itemClass2", p."itemClass2", '''')::text AS ic2,
                COALESCE(d."itemClass3", p."itemClass3", '''')::text AS ic3,
                COALESCE(d."itemClass4", p."itemClass4", '''')::text AS ic4,
                COALESCE(h."commercialOfferItemClass1", d."itemClass1", p."itemClass1", '''')::text AS comofferic1,
                COALESCE(d."incrementalTrade$", 0)::numeric AS incrementaltmdollar,
                COALESCE(d."incrementalSales", 0)::numeric AS incrementalsalesdollar,
                COALESCE(d."everydayCost", 0)::numeric AS edcost,

                ROUND(
                    COALESCE(d."everydayPriceGst", 0)
                    - COALESCE(d."everydayCost", d."nationalAverageCost", d."leCost", d."LatestEffectiveCost", 0),
                    2
                )::numeric AS edunittmdollar,

                ROUND(
                    COALESCE(d."advertisedPriceGst", 0)
                    - COALESCE(d."everydayCost", d."nationalAverageCost", d."leCost", d."LatestEffectiveCost", 0),
                    2
                )::numeric AS advunittmdollar,

                ROUND(COALESCE(d."advertisedPriceGst", 0) * COALESCE(d."categoryforecast", 0), 2)::numeric AS advsalesdollar,
                ROUND(COALESCE(d."everydayPriceGst", 0) * COALESCE(d."categoryforecast", 0), 2)::numeric AS edsalesdollar,

                /* ===================================================
                 * SpendX Tiers (Pulled directly from tEventOffer header)
                 * =================================================== */
                COALESCE(h."spend1", 0)::numeric AS spend1,
                COALESCE(h."savePct1", 0)::numeric AS savepct1,
                h."spend2"::numeric AS spend2,
                h."savePct2"::numeric AS savepct2,
                h."spend3"::numeric AS spend3,
                h."savePct3"::numeric AS savepct3,
                COALESCE(h."spend2" IS NOT NULL AND h."spend2" > 0, FALSE)::boolean AS istiered,

                ROUND(
                    COALESCE(
                        d."advertisedPrice",
                        CASE
                            WHEN COALESCE(d."everydayPrice", 0) > 0 AND COALESCE(d."everydayPriceGst", 0) > 0
                            THEN d."advertisedPriceGst" / (d."everydayPriceGst" / d."everydayPrice")
                            ELSE d."advertisedPriceGst" / 1.10
                        END,
                        0
                    ), 2
                )::numeric AS advpriceexgst,

                COALESCE(d."isCategoryForecastLocked", FALSE) AS iscatfcstlocked,
                COUNT(*) OVER()::integer AS total_count,
                COALESCE(d."isSkuEdited", FALSE) AS isskuedited,
                COALESCE(d."isSkuActive", TRUE) AS isskuactive,
                COALESCE(d."isFromPriceOverridden", FALSE) AS isfrompriceoverriden

            FROM ' || v_tbl || ' d
            LEFT JOIN ' || v_hdr_tbl || ' h
                ON d."offerId" = h."offerId"
               AND d."offerNo" = h."offerNumber"
            LEFT JOIN ' || v_prod_tbl || ' p
                ON d."sku" = p."sku"
               AND p."country" = h."country"
            WHERE d."offerId" = $1
              AND d."offerNo" = $2
              ' || v_where || '
        )
        SELECT
            f.sku, f.part_number, f.brand, f.description, f.frompriceind, f.displayind,
            f.clearance, f.showroom, f.advpricegst, f.edprice, f.edpricegst, f.futureedprice,
            f.futureedeffectivedate, f.calcsavepercent, f.calcsavevalue, f.lecost, f.natavgcost,
            f.catfcst, f.incrfcst, f.fcstcost, f.fcstsales, f.fcsttmvalue, f.fcsttmpercent,
            f.edunits, f.scansupportvalue, f.scansupportpercent, f.sohstore, f.sohdc,
            f.grp0qty, f.grp1qty, f.grp2qty, f.grp3qty, f.grp4qty, f.grp5qty,
            f.totaltieup, f.tieuppercentfcst, f.tieupcost, f.supplierid, f.suppliername,
            f.ic2, f.ic3, f.ic4, f.comofferic1, f.incrementaltmdollar, f.incrementalsalesdollar,
            f.edcost, f.edunittmdollar, f.advunittmdollar, f.advsalesdollar, f.edsalesdollar,
            f.spend1, f.savepct1, f.spend2, f.savepct2, f.spend3, f.savepct3, f.istiered,
            f.advpriceexgst, f.iscatfcstlocked, f.total_count, f.isskuedited, f.isskuactive,
            f.isfrompriceoverriden
        FROM filtered f
        ' || v_order || '
        LIMIT $4 OFFSET $3';

    RETURN QUERY EXECUTE v_sql
        USING p_offer_id, p_offer_no, v_offset, v_page_sz;
END;
$BODY$;
