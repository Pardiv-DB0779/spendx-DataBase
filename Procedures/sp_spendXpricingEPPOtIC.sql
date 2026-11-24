-- FUNCTION: public.spSpendXPricingEPPOtIC
-- Purpose-built for SpendX Pricing Extract filtering (Offer Types 18 & 118) across the 5 core tables.

DROP FUNCTION IF EXISTS public."spSpendXPricingEPPOtIC"(integer, integer, integer, varchar, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS public.spspendxpricingeppotic(integer, integer, integer, varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION public.spspendxpricingeppotic(
    p_eventid integer,
    p_page integer DEFAULT NULL,
    p_pageposn integer DEFAULT NULL,
    p_comoffertypeid varchar DEFAULT NULL,
    p_comofferic varchar DEFAULT NULL,
    p_criteria varchar DEFAULT NULL,
    p_fieldlist varchar DEFAULT '*'
)
RETURNS TABLE
(
    "EVENTDESC" varchar,
    "PAGE" integer,
    "PAGEPOSN" integer,
    "COMOFFERTYPE" varchar,
    "COMOFFERIC1" varchar,
    "PARTNO" varchar,
    "DESC" varchar,
    "BRAND" varchar,
    "SKU" varchar,
    "EDPRICEGST" numeric,
    "STARTDTE" date,
    "ENDDTE" date,
    "SPEND1" numeric,
    "SPEND2" numeric,
    "SPEND3" numeric,
    "SAVEPCT1" numeric,
    "SAVEPCT2" numeric,
    "SAVEPCT3" numeric,
    "ADVPRICEGST" numeric,
    "ISREWARDS" boolean
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_sql text;
    v_crit text;
BEGIN
    v_crit := 'eo."eventId" = ' || p_eventid;

    IF p_page IS NOT NULL THEN
        v_crit := v_crit || ' AND eo."page" = ' || p_page;
    END IF;

    IF p_pageposn IS NOT NULL THEN
        v_crit := v_crit || ' AND eo."pagePosition" = ' || p_pageposn;
    END IF;

    IF p_comoffertypeid IS NOT NULL AND p_comoffertypeid <> '' THEN
        v_crit := v_crit || ' AND eo."offerTypeId" IN (' || p_comoffertypeid || ')';
    ELSE
        v_crit := v_crit || ' AND eo."offerTypeId" IN (18, 118)';
    END IF;

    IF p_comofferic IS NOT NULL AND p_comofferic <> '' THEN
        v_crit := v_crit || ' AND COALESCE(eo."commercialOfferItemClass1", eod."itemClass1", prod."itemClass1", '''') = ' || quote_literal(p_comofferic);
    END IF;

    IF p_criteria IS NOT NULL AND p_criteria <> '' THEN
        v_crit := v_crit || ' AND (' || p_criteria || ')';
    END IF;

    v_sql := '
        SELECT ' || p_fieldlist || '
        FROM
        (
            SELECT
                COALESCE(eo."offerName", '''')::varchar AS "EVENTDESC",
                eo."page" AS "PAGE",
                CASE
                    WHEN eo."pagePosition" = 0 THEN eo."offerId"
                    ELSE eo."pagePosition"
                END AS "PAGEPOSN",
                COALESCE(eo."commercialOfferType", eo."offerType", '''')::varchar AS "COMOFFERTYPE",
                COALESCE(eo."commercialOfferItemClass1", eod."itemClass1", prod."itemClass1", '''')::varchar AS "COMOFFERIC1",
                COALESCE(eod."partNo", prod."partNo", eod."sku")::varchar AS "PARTNO",
                COALESCE(eod."description", prod."description", '''')::varchar AS "DESC",
                COALESCE(eod."brand", prod."brand", eo."brand")::varchar AS "BRAND",
                eod."sku"::varchar AS "SKU",
                COALESCE(eod."everydayPriceGst", prod."everydayPriceGst", 0)::numeric AS "EDPRICEGST",
                eo."createdAt"::date AS "STARTDTE",
                (eo."createdAt" + interval ''14 days'')::date AS "ENDDTE",
                COALESCE(eo."spend1", 0)::numeric AS "SPEND1",
                eo."spend2"::numeric AS "SPEND2",
                eo."spend3"::numeric AS "SPEND3",
                COALESCE(eo."savePct1", 0)::numeric AS "SAVEPCT1",
                eo."savePct2"::numeric AS "SAVEPCT2",
                eo."savePct3"::numeric AS "SAVEPCT3",
                ROUND(COALESCE(eod."advertisedPriceGst", 0), 2)::numeric AS "ADVPRICEGST",
                COALESCE(eo."isRewards", FALSE)::boolean AS "ISREWARDS"
            FROM public."tEventOffer" eo
            INNER JOIN public."teventofferdetail" eod
                ON eo."offerId" = eod."offerId"
               AND eo."offerNumber" = eod."offerNo"
               AND (eod."isSkuActive" = TRUE OR eod."isSkuActive" IS NULL)
            LEFT JOIN public."tproducts" prod
                ON eod."sku" = prod."sku"
               AND prod."country" = eo."country"
            WHERE ' || v_crit || '
              AND (eo."isOfferActive" = TRUE OR eo."isOfferActive" IS NULL)
        ) s
        ORDER BY
            "PAGE",
            "PAGEPOSN",
            "COMOFFERIC1",
            "PARTNO";
    ';

    RETURN QUERY EXECUTE v_sql;
END;
$BODY$;

-- CamelCase synonym:
CREATE OR REPLACE FUNCTION public."spSpendXPricingEPPOtIC"(
    p_eventid integer,
    p_page integer DEFAULT NULL,
    p_pageposn integer DEFAULT NULL,
    p_comoffertypeid varchar DEFAULT NULL,
    p_comofferic varchar DEFAULT NULL,
    p_criteria varchar DEFAULT NULL,
    p_fieldlist varchar DEFAULT '*'
)
RETURNS TABLE
(
    "EVENTDESC" varchar,
    "PAGE" integer,
    "PAGEPOSN" integer,
    "COMOFFERTYPE" varchar,
    "COMOFFERIC1" varchar,
    "PARTNO" varchar,
    "DESC" varchar,
    "BRAND" varchar,
    "SKU" varchar,
    "EDPRICEGST" numeric,
    "STARTDTE" date,
    "ENDDTE" date,
    "SPEND1" numeric,
    "SPEND2" numeric,
    "SPEND3" numeric,
    "SAVEPCT1" numeric,
    "SAVEPCT2" numeric,
    "SAVEPCT3" numeric,
    "ADVPRICEGST" numeric,
    "ISREWARDS" boolean
)
LANGUAGE sql
AS $BODY$
    SELECT * FROM public.spspendxpricingeppotic(p_eventid, p_page, p_pageposn, p_comoffertypeid, p_comofferic, p_criteria, p_fieldlist);
$BODY$;
