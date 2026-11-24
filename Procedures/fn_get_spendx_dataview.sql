-- FUNCTION: public.fn_get_spendx_dataview(integer, integer, text[], text[], text[], text[], boolean, boolean, integer, integer)

DROP FUNCTION IF EXISTS public.fn_get_spendx_dataview(integer, integer, text[], text[], text[], text[], boolean, boolean, integer, integer);

CREATE OR REPLACE FUNCTION public.fn_get_spendx_dataview(
    p_offer_id integer DEFAULT 1,
    p_offer_no integer DEFAULT 1,
    p_skus text[] DEFAULT NULL::text[],
    p_part_numbers text[] DEFAULT NULL::text[],
    p_brands text[] DEFAULT NULL::text[],
    p_part_descriptions text[] DEFAULT NULL::text[],
    p_sort_edprice_desc boolean DEFAULT NULL::boolean,
    p_sort_catfcst_desc boolean DEFAULT NULL::boolean,
    p_page_number integer DEFAULT 1,
    p_page_size integer DEFAULT 100)
RETURNS TABLE(
    sku text,
    part_number text,
    brand text,
    description text,
    edprice numeric,
    edpricegst numeric,
    lecost numeric,
    natavgcost numeric,
    catfcst integer,
    incrfcst integer,
    edunits numeric,
    fcstcost numeric,
    fcstsales numeric,
    fcsttmvalue numeric,
    fcsttmpercent numeric,
    sohstore integer,
    sohdc integer,
    totaltieup integer,
    tieupcost numeric,
    scansupportvalue numeric,
    scansupportpercent numeric,
    displayind boolean,
    clearance text,
    showroom text,
    iscatfcstlocked boolean,
    isskuedited boolean,
    isskuactive boolean,
    total_count integer
)
LANGUAGE 'plpgsql'
COST 100
VOLATILE
AS $BODY$
DECLARE
    v_sql TEXT;
    v_where TEXT := '';
    v_order TEXT := ' ORDER BY d."sku" ';
    v_offset INT := GREATEST(0, (COALESCE(p_page_number, 1) - 1) * GREATEST(1, COALESCE(p_page_size, 100)));
    v_limit INT := GREATEST(1, COALESCE(p_page_size, 100));
BEGIN
    -- 1. Filter SKUs
    IF p_skus IS NOT NULL AND array_length(p_skus, 1) > 0 THEN
        v_where := v_where || ' AND (' ||
            array_to_string(ARRAY(SELECT format('d."sku" ILIKE %L', s || '%') FROM unnest(p_skus) s), ' OR ')
            || ') ';
    END IF;

    -- 2. Filter Part Numbers
    IF p_part_numbers IS NOT NULL AND array_length(p_part_numbers, 1) > 0 THEN
        v_where := v_where || ' AND (' ||
            array_to_string(ARRAY(SELECT format('d."partNo" ILIKE %L', s || '%') FROM unnest(p_part_numbers) s), ' OR ')
            || ') ';
    END IF;

    -- 3. Filter Brands
    IF p_brands IS NOT NULL AND array_length(p_brands, 1) > 0 THEN
        v_where := v_where || ' AND (' ||
            array_to_string(ARRAY(SELECT format('d."brand" ILIKE %L', s || '%') FROM unnest(p_brands) s), ' OR ')
            || ') ';
    END IF;

    -- 4. Filter Descriptions (Substring search '%s%')
    IF p_part_descriptions IS NOT NULL AND array_length(p_part_descriptions, 1) > 0 THEN
        v_where := v_where || ' AND (' ||
            array_to_string(ARRAY(SELECT format('d."description" ILIKE %L', '%' || s || '%') FROM unnest(p_part_descriptions) s), ' OR ')
            || ') ';
    END IF;

    -- 5. Sorting
    IF p_sort_edprice_desc IS NOT NULL THEN
        v_order := ' ORDER BY d."everydayPrice" ' || CASE WHEN p_sort_edprice_desc THEN 'DESC NULLS LAST' ELSE 'ASC NULLS FIRST' END || ', d."sku" ';
    ELSIF p_sort_catfcst_desc IS NOT NULL THEN
        v_order := ' ORDER BY d."categoryforecast" ' || CASE WHEN p_sort_catfcst_desc THEN 'DESC NULLS LAST' ELSE 'ASC NULLS FIRST' END || ', d."sku" ';
    END IF;

    -- 6. Paged SQL with Window Function COUNT(*) OVER()
    v_sql := '
        WITH filtered AS (
            SELECT
                d."sku"::text                                                  AS sku,
                COALESCE(d."partNo", d."sku")::text                             AS part_number,
                COALESCE(d."brand", '''')::text                                 AS brand,
                COALESCE(d."description", '''')::text                           AS description,
                COALESCE(d."everydayPrice", 0)::numeric                         AS edprice,
                COALESCE(d."everydayPriceGst", 0)::numeric                      AS edpricegst,
                COALESCE(d."leCost", 0)::numeric                                AS lecost,
                COALESCE(d."nationalAverageCost", 0)::numeric                   AS natavgcost,
                COALESCE(d."categoryforecast", 0)::integer                      AS catfcst,
                COALESCE(d."incrementalForecast", 0)::integer                   AS incrfcst,
                COALESCE(d."everydayUnits", 0)::numeric                         AS edunits,
                COALESCE(d."forecastCost", 0)::numeric                          AS fcstcost,
                COALESCE(d."forecastSales", 0)::numeric                         AS fcstsales,
                COALESCE(d."forecastTradeMargin$", 0)::numeric                  AS fcsttmvalue,
                COALESCE(d."forecastTradeMargin%", 0)::numeric                  AS fcsttmpercent,
                COALESCE(d."stockOnHandStore", 0)::integer                      AS sohstore,
                COALESCE(d."stockOnHandDc", 0)::integer                         AS sohdc,
                COALESCE(d."totalTieUp", 0)::integer                            AS totaltieup,
                COALESCE(d."tieUpCost", 0)::numeric                             AS tieupcost,
                COALESCE(d."scanSupportValue", 0)::numeric                      AS scansupportvalue,
                COALESCE(d."scanSupportPercent", 0)::numeric                    AS scansupportpercent,
                COALESCE(d."displayIndicator", true)::boolean                   AS displayind,
                d."clearanceIndicator"::text                                    AS clearance,
                d."showroomIndicator"::text                                     AS showroom,
                COALESCE(d."isCategoryForecastLocked", false)::boolean          AS iscatfcstlocked,
                COALESCE(d."isSkuEdited", false)::boolean                        AS isskuedited,
                COALESCE(d."isSkuActive", true)::boolean                        AS isskuactive,
                COUNT(*) OVER()::integer                                        AS total_count
            FROM public."teventofferdetail" d
            WHERE d."offerId" = ' || p_offer_id || '
              AND d."offerNo" = ' || p_offer_no || '
              AND (d."isSkuActive" = TRUE OR d."isSkuActive" IS NULL) '
              || v_where || '
        )
        SELECT
            f.sku,
            f.part_number,
            f.brand,
            f.description,
            f.edprice,
            f.edpricegst,
            f.lecost,
            f.natavgcost,
            f.catfcst,
            f.incrfcst,
            f.edunits,
            f.fcstcost,
            f.fcstsales,
            f.fcsttmvalue,
            f.fcsttmpercent,
            f.sohstore,
            f.sohdc,
            f.totaltieup,
            f.tieupcost,
            f.scansupportvalue,
            f.scansupportpercent,
            f.displayind,
            f.clearance,
            f.showroom,
            f.iscatfcstlocked,
            f.isskuedited,
            f.isskuactive,
            f.total_count
        FROM filtered f
        ' || v_order || '
        OFFSET ' || v_offset || '
        LIMIT ' || v_limit || ';';

    RETURN QUERY EXECUTE v_sql;
END;
$BODY$;
