CREATE TABLE IF NOT EXISTS public."teventofferdetail" (
    "offerId"                    INT NOT NULL,
    "offerNo"                    INT NOT NULL,
    "sku"                        VARCHAR(50) NOT NULL,
    "partNo"                     VARCHAR(50),
    "description"                VARCHAR(255),
    "brand"                      VARCHAR(100),
    "itemClass1"                 VARCHAR(50),
    "itemClass2"                 VARCHAR(50),
    "itemClass3"                 VARCHAR(50),
    "itemClass4"                 VARCHAR(50),
    "unitOfMeasureCopy"          VARCHAR(50),
    "substituteSku"              VARCHAR(50),

    
    "everydayPrice"              NUMERIC(19, 5),
    "everydayPriceGst"           NUMERIC(19, 5),
    "everydayPriceGstSys"        NUMERIC(19, 5),
    "advertisedPrice"            NUMERIC(19, 5),
    "advertisedPriceGst"         NUMERIC(19, 5),
    "calculatedSavePercentage"   NUMERIC(19, 5),
    "calculatedSaveValue"        NUMERIC(19, 5),
    "fromPriceIndicator"         BOOLEAN DEFAULT FALSE,
    "isFromPriceOverridden"      BOOLEAN DEFAULT FALSE,

   
    "everydayUnits"              NUMERIC(19, 5) DEFAULT 0,
    "forecastUnits"              NUMERIC(19, 5) DEFAULT 0,
    "categoryforecast"           INT DEFAULT 0,
    "incrementalForecast"        INT DEFAULT 0,
    "forecastCost"               NUMERIC(19, 5) DEFAULT 0,
    "forecastSales"              NUMERIC(19, 5) DEFAULT 0,
    "forecastTradeMargin$"       NUMERIC(19, 5) DEFAULT 0,
    "forecastTradeMargin%"       NUMERIC(19, 5) DEFAULT 0,
    "everydayTradeMargin$"       NUMERIC(19, 5) DEFAULT 0,
    "everydayTradeMargin%"       NUMERIC(19, 5) DEFAULT 0,
    "incrementalSales"           NUMERIC(19, 5) DEFAULT 0,
    "incrementalTrade$"          NUMERIC(19, 5) DEFAULT 0,

    
    "scanSupport$"               NUMERIC(19, 5) DEFAULT 0,
    "scanSupport%"               NUMERIC(19, 5) DEFAULT 0,
    "scanSupportValue"           NUMERIC(19, 5) DEFAULT 0,
    "scanSupportPercent"         NUMERIC(19, 5) DEFAULT 0,
    "leCost"                     NUMERIC(19, 5),
    "LatestEffectiveCost"        NUMERIC(19, 5),
    "nationalAverageCost"        NUMERIC(19, 5),
    "categoryCost"               NUMERIC(19, 5),
    "vendorCostPerEach"          NUMERIC(19, 5),
    "everydayCost"               NUMERIC(19, 5),
    "everydayExtendedUnitCost"   NUMERIC(19, 5),
    "everydayExtendedUnitSales"  NUMERIC(19, 5),
    "extendedAdvertisedPrice"    NUMERIC(19, 5),

   
    "futureEdPrice"              NUMERIC(19, 5),
    "futureEdEffectiveDate"      TIMESTAMPTZ,

    
    "clearanceIndicator"         VARCHAR(5),
    "showroomIndicator"          VARCHAR(5),
    "stockOnHandStore"           NUMERIC(19, 5),
    "stockOnHandDc"              NUMERIC(19, 5),
    "stockOnHandDC"              NUMERIC(19, 5),
    "isSkuActive"                BOOLEAN DEFAULT TRUE,
    "isSkuEdited"                BOOLEAN DEFAULT FALSE,
    "displayIndicator"           BOOLEAN DEFAULT TRUE,
    "isCategoryForecastLocked"   BOOLEAN DEFAULT FALSE,

    
    "G0"                         INT,
    "G1"                         INT,
    "G2"                         INT,
    "G3"                         INT,
    "G4"                         INT,
    "G5"                         INT,
    "group0Quantity"             INT DEFAULT 0,
    "group1Quantity"             INT DEFAULT 0,
    "group2Quantity"             INT DEFAULT 0,
    "group3Quantity"             INT DEFAULT 0,
    "group4Quantity"             INT DEFAULT 0,
    "group5Quantity"             INT DEFAULT 0,
    "totalTieUp"                 INT DEFAULT 0,
    "tieUpCost"                  NUMERIC(19, 5) DEFAULT 0,
    "pricePoint6"                NUMERIC(19, 5),
    "pricePoint6IncludingGst"    NUMERIC(19, 5),

    
    "page"                       INT NOT NULL DEFAULT 1,
    "pagePosition"               INT NOT NULL DEFAULT 1,

    CONSTRAINT pk_teventofferdetail PRIMARY KEY ("offerId", "offerNo", "sku")
);

CREATE INDEX IF NOT EXISTS idx_teventofferdetail_sku ON public."teventofferdetail" ("sku");
CREATE INDEX IF NOT EXISTS idx_teventofferdetail_offer ON public."teventofferdetail" ("offerId", "offerNo");