USE [FUNBOX_BILL_DB]
GO
/****** Object:  StoredProcedure [dbo].[UP_ITEM_GIFT4CC_TX_CHA]    Script Date: 09/16/2010 09:33:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------
-- ProcedureName   : UP_ITEM_GIFT4CC_TX_CHA
-- Description     : 아이템 선물
-- Inner SP        : UP_ACCT_INFO_NT_GET
--                   UP_BADUSER_NT_CHK
--                   UP_KEY_NT_GEN
-- Return Value    : 0:Success, <>0:Failure
-- Copyright ? 2007 by PayLetter Inc. All rights reserved.
-- Author          : shadow54@payletter.com, 2009-06-10
-- Modify History  : Just Create

-- test.....
-----------------------------------------------------------------
ALTER PROCEDURE [dbo].[UP_ITEM_GIFT4CC_TX_CHA]
@pi_strSiteCode                 VARCHAR(15),
@pi_intUserNo                   INT,
@pi_strUserID                   VARCHAR(50)=NULL,
@pi_strUserName                 NVARCHAR(50)=NULL,
@pi_strItemID                   VARCHAR(256)=NULL,

@pi_strItemCnt                  VARCHAR(128)=NULL,
@pi_strGameCode                 VARCHAR(15)=NULL,
@pi_strGameItemID               VARCHAR(256)=NULL,
@pi_strChargeAmt                VARCHAR(256)=NULL,
@pi_strProdName                 NVARCHAR(512)=NULL,

@pi_strIPAddr                   VARCHAR(50)=NULL,
@pi_intCashNo                   BIGINT=NULL,
@pi_intRUserNo                   INT=NULL,
@pi_strRUserID                   VARCHAR(50)=NULL,
@pi_strLocation                 VARCHAR(5)=NULL,

@po_strChargeNo                 VARCHAR(512)    OUTPUT,
@po_intChargedAmt               MONEY           OUTPUT,
@po_strServiceURL               VARCHAR(1024)   OUTPUT,
@po_intCashReal                 MONEY           OUTPUT,
@po_intCashBonus                MONEY           OUTPUT,

@po_intMileage                  MONEY           OUTPUT,
@po_intTINCashReal              MONEY           OUTPUT,
@po_intTOUTCashReal             MONEY           OUTPUT,
@po_intTINCashBonus             MONEY           OUTPUT,
@po_intTOUTCashBonus            MONEY           OUTPUT,

@po_intTINMileage               MONEY           OUTPUT,
@po_intTOUTMileage              MONEY           OUTPUT,
@po_intMileageAdded             MONEY           OUTPUT,
@po_strEventChargeNo            VARCHAR(512)    OUTPUT,
@po_strEventCPItemID            VARCHAR(256)    OUTPUT,

@po_strCPItemID                 VARCHAR(512)    OUTPUT,
@po_strErrMsg                   VARCHAR(256)    OUTPUT,
@po_intRetVal                   INT             OUTPUT,
@po_strDBErrMsg                 VARCHAR(256)    OUTPUT,
@po_intDBRetVal                 INT             OUTPUT 
AS
SET NOCOUNT ON

IF @@TRANCOUNT <> 0 BEGIN
    ROLLBACK TRAN
END

DECLARE @v_intPresentFlag       INT
DECLARE @v_strDelimiter         CHAR(1)
DECLARE @v_intItemIDCnt         INT
DECLARE @v_intItemCntCnt        INT
DECLARE @v_intChargeAmtCnt      INT
DECLARE @v_intGameItemIDCnt     INT
DECLARE @v_intLoop              INT
DECLARE @v_intTotalCnt          INT
DECLARE @v_intChargeNo          BIGINT
DECLARE @v_intEventChargeNo     BIGINT
DECLARE @v_strEventCPItemID     VARCHAR(50)
DECLARE @v_strServiceURL        VARCHAR(256)
DECLARE @v_intItemID            INT
DECLARE @v_intItemCnt           INT
DECLARE @v_strGameItemID        VARCHAR(50)
DECLARE @v_intChargeAmt         INT
DECLARE @v_strProdName          VARCHAR(50)
DECLARE @v_intGChargeNo         BIGINT
DECLARE @v_intChargedAmt        MONEY
DECLARE @v_strCPItemID          VARCHAR(50)

BEGIN TRY
    SET @v_strDelimiter = CHAR(11)

    SET @v_intPresentFlag = 2   -- 선물

    SET @v_intItemIDCnt         = dbo.UF_CNT_DELIMITER_PARSE(@pi_strItemID,         @v_strDelimiter)
    SET @v_intItemCntCnt        = dbo.UF_CNT_DELIMITER_PARSE(@pi_strItemCnt,        @v_strDelimiter)
    SET @v_intChargeAmtCnt      = dbo.UF_CNT_DELIMITER_PARSE(@pi_strChargeAmt,      @v_strDelimiter)
    SET @v_intGameItemIDCnt     = dbo.UF_CNT_DELIMITER_PARSE(@pi_strGameItemID,     @v_strDelimiter)

    IF ISNULL(@pi_strItemID,'') <> '' AND @v_intItemIDCnt > 0 AND @v_intItemIDCnt <> @v_intItemCntCnt BEGIN
        SET @po_strErrMsg = 'The count of ItemID and the count of purchase request does not match.'
        SET @po_intRetVal = 2003
        RETURN
    END

    IF ISNULL(@pi_strChargeAmt,'') <> '' AND @v_intChargeAmtCnt > 0 AND @v_intItemCntCnt <> @v_intChargeAmtCnt BEGIN
        SET @po_strErrMsg = 'The count of amount setting and the count of itemID or the count of purchase requests does not match.'
        SET @po_intRetVal = 2004
        RETURN
    END

    IF ISNULL(@pi_strGameItemID,'') <> '' AND @v_intGameItemIDCnt > 0 AND @v_intItemCntCnt <> @v_intGameItemIDCnt BEGIN
        SET @po_strErrMsg = 'The count of ItemID and the count of purchase request does not match.'
        SET @po_intRetVal = 2005
        RETURN
    END

    IF ISNULL(@pi_strItemID,'') = '' AND ISNULL(@pi_strGameItemID,'') = '' BEGIN
        SET @po_strErrMsg = 'Item ID not set.'
        SET @po_intRetVal = 2006
        RETURN
    END

    SET @v_intTotalCnt = @v_intItemCntCnt

    ------------------------------------------------------
    --TRANSACTION START
    ------------------------------------------------------
    BEGIN TRAN
    
        SET @v_intLoop = 1
        SET @po_strChargeNo = ''
        SET @po_strEventChargeNo = ''
        SET @po_strEventCPItemID = ''
        SET @po_strServiceURL = ''
        SET @v_intGChargeNo = NULL
        SET @po_intChargedAmt = 0
        SET @v_intChargedAmt = 0
        SET @po_strCPItemID = ''
        
        WHILE @v_intLoop <= @v_intTotalCnt BEGIN
        
            SET @v_intItemID        = CAST(dbo.UF_GET_STRSPLIT(@pi_strItemID,@v_strDelimiter,@v_intLoop) AS INT)
            SET @v_intItemCnt       = CAST(dbo.UF_GET_STRSPLIT(@pi_strItemCnt,@v_strDelimiter,@v_intLoop) AS INT)
            SET @v_strGameItemID    = dbo.UF_GET_STRSPLIT(@pi_strGameItemID,@v_strDelimiter,@v_intLoop)
            SET @v_intChargeAmt     = CAST(dbo.UF_GET_STRSPLIT(@pi_strChargeAmt,@v_strDelimiter,@v_intLoop) AS INT)
            SET @v_strProdName      = dbo.UF_GET_STRSPLIT(@pi_strProdName,@v_strDelimiter,@v_intLoop)

            EXEC UP_PURCHASE_NT_CHA @pi_strSiteCode, @pi_intUserNo, @pi_strUserID, @pi_strUserName, @v_intItemID 
                                   ,@v_intItemCnt, @pi_strGameCode, @v_strGameItemID, @v_intChargeAmt, @v_strProdName 
                                   ,@pi_strIPAddr, @pi_intCashNo, @v_intPresentFlag, @pi_intRUserNo, @pi_strRUserID 
                                   ,@pi_strLocation, @v_intGChargeNo, @v_intChargeNo OUTPUT, @v_intChargedAmt OUTPUT, @v_strServiceURL OUTPUT
                                   ,@po_intCashReal OUTPUT, @po_intCashBonus OUTPUT, @po_intMileage OUTPUT, @po_intTINCashReal OUTPUT, @po_intTOUTCashReal OUTPUT
                                   ,@po_intTINCashBonus OUTPUT, @po_intTOUTCashBonus OUTPUT, @po_intTINMileage OUTPUT, @po_intTOUTMileage OUTPUT, @po_intMileageAdded OUTPUT
                                   ,@v_intEventChargeNo OUTPUT, @v_strEventCPItemID OUTPUT, @v_strCPItemID OUTPUT, NULL, @po_strErrMsg OUTPUT
                                   ,@po_intRetVal OUTPUT, @po_strDBErrMsg OUTPUT, @po_intDBRetVal OUTPUT

            IF @po_intRetVal <> 0 BEGIN
                ROLLBACK TRAN
                RETURN
            END

            IF @v_intLoop = 1 BEGIN
                SET @v_intGChargeNo = @v_intChargeNo
            END

            IF @v_intLoop > 1 BEGIN
                SET @po_strChargeNo         = @po_strChargeNo + @v_strDelimiter
                SET @po_strServiceURL       = @po_strServiceURL + @v_strDelimiter
                IF ISNULL(@v_intEventChargeNo,0) <> 0 BEGIN
                    SET @po_strEventChargeNo    = @po_strEventChargeNo + @v_strDelimiter
                END
                IF ISNULL(@v_strEventCPItemID,'') <> '' BEGIN
                    SET @po_strEventCPItemID    = @po_strEventCPItemID + @v_strDelimiter
                END
                IF ISNULL(@v_strCPItemID,'') <> '' BEGIN
                    SET @po_strCPItemID    = @po_strCPItemID + @v_strDelimiter
                END
            END

            SET @po_strChargeNo         = @po_strChargeNo + CAST(@v_intChargeNo AS VARCHAR)
            SET @po_strServiceURL       = @po_strServiceURL + @v_strServiceURL
            IF ISNULL(@v_intEventChargeNo,0) <> 0 BEGIN
                SET @po_strEventChargeNo    = @po_strEventChargeNo + CAST(@v_intEventChargeNo AS VARCHAR)
            END
            IF ISNULL(@v_strEventCPItemID,'') <> '' BEGIN
                SET @po_strEventCPItemID    = @po_strEventCPItemID + @v_strEventCPItemID
            END
            IF ISNULL(@v_strCPItemID,'') <> '' BEGIN
                SET @po_strCPItemID    = @po_strCPItemID + @v_strCPItemID
            END

            SET @po_intChargedAmt = @po_intChargedAmt + @v_intChargedAmt        
            SET @v_intLoop = @v_intLoop + 1
        END

    COMMIT TRAN
    ------------------------------------------------------
    --TRANSACTION END
    ------------------------------------------------------

    SET @po_strErrMsg = 'OK'
    SET @po_intRetVal = 0
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN
    SET @po_strErrMsg   = 'Unexpected error occurred'
    SET @po_intRetVal   = 2000
    SET @po_strDBErrMsg = ERROR_MESSAGE() + '(' + ERROR_PROCEDURE() + ':' + CAST(ERROR_LINE() AS VARCHAR) + ')'
    SET @po_intDBRetVal = ERROR_NUMBER()
END CATCH

RETURN