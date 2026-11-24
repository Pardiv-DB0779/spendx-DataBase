-- FUNCTION: public.spSpendXPricingByEventID(integer)
-- Purpose-built for SpendX Pricing Extract (Offer Types 18 & 118) across the 5 core tables.

DROP FUNCTION IF EXISTS public."spSpendXPricingByEventID"(integer);
DROP FUNCTION IF EXISTS public.spspendxpricingbyeventid(integer);

CREATE OR REPLACE FUNCTION public.spspendxpricingbyeventid(
    p_eventid integer
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
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(eo."offerName", '')::varchar AS "EVENTDESC",
        eo."page" AS "PAGE",
        CASE
            WHEN eo."pagePosition" = 0 THEN eo."offerId"
            ELSE eo."pagePosition"
        END AS "PAGEPOSN",
        COALESCE(eo."commercialOfferType", eo."offerType", '')::varchar AS "COMOFFERTYPE",
        COALESCE(eo."commercialOfferItemClass1", eod."itemClass1", prod."itemClass1", '')::varchar AS "COMOFFERIC1",
        COALESCE(eod."partNo", prod."partNo", eod."sku")::varchar AS "PARTNO",
        COALESCE(eod."description", prod."description", '')::varchar AS "DESC",
        COALESCE(eod."brand", prod."brand", eo."brand")::varchar AS "BRAND",
        eod."sku"::varchar AS "SKU",
        COALESCE(eod."everydayPriceGst", prod."everydayPriceGst", 0)::numeric AS "EDPRICEGST",
        eo."createdAt"::date AS "STARTDTE",
        (eo."createdAt" + interval '14 days')::date AS "ENDDTE",
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
    WHERE eo."eventId" = p_eventid
      AND eo."offerTypeId" IN (18, 118)
      AND (eo."isOfferActive" = TRUE OR eo."isOfferActive" IS NULL)
    ORDER BY
        eo."page",
        eo."pagePosition",
        "COMOFFERIC1",
        "PARTNO";
END;
$BODY$;

-- Alias for quoted camelCase invocation:
CREATE OR REPLACE FUNCTION public."spSpendXPricingByEventID"(p_eventid integer)
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
    SELECT * FROM public.spspendxpricingbyeventid(p_eventid);
$BODY$;
