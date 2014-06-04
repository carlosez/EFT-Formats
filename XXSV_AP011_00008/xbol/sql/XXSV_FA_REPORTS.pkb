create or replace package body XXSV_FA_REPORTS  as

    procedure CIP_ADDITIONS( ECODE out varchar2 
                            ,ebuff out varchar2 
                            ,pin_ledger_id  number
                            ,pin_as_of_date varchar2
                            ,pin_book_type  varchar2
                            ,pin_project    varchar2
                            ) is

cursor cip_data is 
SELECT B.BOOK_TYPE_CODE,
       (SELECT DISTINCT CC.SEGMENT9
          FROM apps.FA_ASSET_INVOICES AI, apps.GL_CODE_COMBINATIONS CC
         WHERE     AI.PAYABLES_CODE_COMBINATION_ID = CC.CODE_COMBINATION_ID
               AND AI.ASSET_ID = A.ASSET_ID
               AND AI.ASSET_INVOICE_ID IN (SELECT MIN (ASSET_INVOICE_ID)
                                             FROM apps.FA_ASSET_INVOICES AI2
                                            WHERE AI2.ASSET_ID = A.ASSET_ID))
          SEGMENT9,
       (SELECT FVT.DESCRIPTION
          FROM apps.FND_FLEX_VALUES FV,
               apps.FND_FLEX_VALUE_SETS FVS,
               apps.FND_FLEX_VALUES_TL FVT
         WHERE     FV.FLEX_VALUE_SET_ID = FVS.FLEX_VALUE_SET_ID
               AND FV.FLEX_VALUE_ID = FVT.FLEX_VALUE_ID
               AND FVS.FLEX_VALUE_SET_NAME = 'XX_GL_MIC_PROJECT_VS'
               AND FVT.LANGUAGE = 'US'
               AND FV.FLEX_VALUE IN
                      (SELECT CC.SEGMENT9
                         FROM apps.FA_ASSET_INVOICES AI,
                              apps.GL_CODE_COMBINATIONS CC
                        WHERE AI.PAYABLES_CODE_COMBINATION_ID =
                                 CC.CODE_COMBINATION_ID
                              AND AI.ASSET_ID = A.ASSET_ID
                              AND AI.ASSET_INVOICE_ID IN
                                     (SELECT MIN (ASSET_INVOICE_ID)
                                        FROM apps.FA_ASSET_INVOICES AI2
                                       WHERE AI2.ASSET_ID = A.ASSET_ID)))
          DESCRIPTION,
       AK.SEGMENT1 || '-' || AK.SEGMENT2 PROYECTO_FA,
       A.ASSET_TYPE,
       A.ASSET_NUMBER,
       DATE_PLACED_IN_SERVICE FECHA_PUESTA_SERVICIO,
       A.SERIAL_NUMBER,
       A.MODEL_NUMBER,
       CT.SEGMENT1 || '-' || CT.SEGMENT2 FA_CATEGORY,
       A.DESCRIPTION asset_DESCRIPTION,
       (SELECT MAX (PO_NUMBER)
          FROM apps.FA_MASS_ADDITIONS MA
         WHERE MA.ASSET_NUMBER = A.ASSET_NUMBER)
          PO_NUMBER,
       B.COST,
          LC.SEGMENT1
       || '-'
       || LC.SEGMENT2
       || '-'
       || LC.SEGMENT3
       || '-'
       || LC.SEGMENT4
       || '-'
       || LC.SEGMENT5
       || '-'
       || LC.SEGMENT6
          LOCATION_CODE,
       FVT1.DESCRIPTION LOCATION_DESCRIPTION,
       (SELECT DP.PERIOD_NAME
          FROM apps.FA_ADJUSTMENTS ADJ, apps.FA_DEPRN_PERIODS DP
         WHERE     SOURCE_TYPE_CODE = 'CIP ADDITION'
               AND ADJUSTMENT_TYPE = 'CIP COST'
               AND ADJ.BOOK_TYPE_CODE = B.BOOK_TYPE_CODE
               AND ASSET_ID = A.ASSET_ID
               AND ADJ.PERIOD_COUNTER_ADJUSTED = DP.PERIOD_COUNTER
               AND ADJ.BOOK_TYPE_CODE = DP.BOOK_TYPE_CODE)
          PERIODO_ADICION
  FROM apps.FA_ADDITIONS A,
       apps.FA_ASSET_KEYWORDS AK,
       apps.FA_BOOKS B,
       apps.FA_TRANSACTION_HEADERS TH,
       apps.FA_CATEGORIES CT,
       apps.FA_LOCATIONS LC,
       apps.FA_DISTRIBUTION_HISTORY DH,
       apps.FND_FLEX_VALUE_SETS FVS1,
       apps.FND_FLEX_VALUES FV1,
       apps.FND_FLEX_VALUES_TL FVT1
 WHERE     A.ASSET_ID = B.ASSET_ID
       AND A.ASSET_KEY_CCID = AK.CODE_COMBINATION_ID
       AND A.ASSET_CATEGORY_ID = CT.CATEGORY_ID
       AND B.BOOK_TYPE_CODE = pin_ledger_id
       AND B.BOOK_TYPE_CODE = TH.BOOK_TYPE_CODE
       AND A.ASSET_ID = TH.ASSET_ID
       AND B.TRANSACTION_HEADER_ID_IN = TH.TRANSACTION_HEADER_ID
       AND (AK.SEGMENT1 || '-' || AK.SEGMENT2) =  NVL (pin_project, (AK.SEGMENT1 || '-' || AK.SEGMENT2))
       AND TH.TRANSACTION_HEADER_ID IN
              (SELECT MAX (TH2.TRANSACTION_HEADER_ID)
                 FROM apps.FA_TRANSACTION_HEADERS TH2
                WHERE TH2.ASSET_ID = A.ASSET_ID
                      AND B.BOOK_TYPE_CODE = TH2.BOOK_TYPE_CODE
                      AND TH2.TRANSACTION_DATE_ENTERED <=
                             TO_DATE (SUBSTR(pin_as_of_date,1,10),
                                      'YYYY/MM/DD HH24:MI:SS')
                      AND TH2.TRANSACTION_TYPE_CODE IN
                             ('CIP ADDITION',
                              'CIP ADJUSTMENT',
                              'FULL RETIREMENT'))
       AND NOT EXISTS
                  (SELECT '1'
                     FROM BOLINF.XXSV_FA_TRANSACTION_HEADERS TH2,
                          BOLINF.XXSV_FA_ADJUSTMENTS ADJ
                    WHERE     TH2.ASSET_ID = A.ASSET_ID
                          AND B.BOOK_TYPE_CODE = TH2.BOOK_TYPE_CODE
                          AND TH2.BOOK_TYPE_CODE = ADJ.BOOK_TYPE_CODE
                          AND TH2.TRANSACTION_HEADER_ID =
                                 ADJ.TRANSACTION_HEADER_ID
                          AND TH2.ASSET_ID = ADJ.ASSET_ID
                          AND TH2.TRANSACTION_DATE_ENTERED <=
                                 TO_DATE (SUBSTR(pin_as_of_date,1,10),
                                          'YYYY/MM/DD HH24:MI:SS')
                          AND ADJ.SOURCE_TYPE_CODE = 'ADDITION'
                          AND ADJUSTMENT_TYPE = 'CIP COST')
       AND FVS1.FLEX_VALUE_SET_NAME = 'XX_FA_MIC_SITE_VS'
       AND FVS1.FLEX_VALUE_SET_ID = FV1.FLEX_VALUE_SET_ID
       AND FV1.FLEX_VALUE = LC.SEGMENT5
       AND FV1.FLEX_VALUE_ID = FVT1.FLEX_VALUE_ID
       AND FVT1.LANGUAGE = 'US'
       AND FV1.PARENT_FLEX_VALUE_LOW = 'SV'
       AND A.ASSET_ID = DH.ASSET_ID
       AND DH.BOOK_TYPE_CODE = B.BOOK_TYPE_CODE
       AND DH.DISTRIBUTION_ID =
              (SELECT MAX (DISTRIBUTION_ID)
                 FROM apps.FA_DISTRIBUTION_HISTORY DH2
                WHERE DH2.ASSET_ID = A.ASSET_ID
                      AND DH2.BOOK_TYPE_CODE = B.BOOK_TYPE_CODE)
       AND DH.DATE_INEFFECTIVE IS NULL
       AND LC.LOCATION_ID = DH.LOCATION_ID
       ;

    V_DELIMITER varchar2 (1):= '|';
    line varchar2(4000);
    begin
        fnd_file.put_line(fnd_file.log,'+-----------------------------------------+');
        fnd_file.put_line(fnd_file.log,'pin_ledger_id   '||pin_ledger_id);
        fnd_file.put_line(fnd_file.log,'pin_as_of_date  '||pin_as_of_date);
        fnd_file.put_line(fnd_file.log,'pin_book_type   '||pin_book_type);
        fnd_file.put_line(fnd_file.log,'+-----------------------------------------+');
        --fnd_file.put_line(fnd_file.output,'Hola mundo!');
        line := '';
        for x in cip_data loop
        line := X.BOOK_TYPE_CODE || V_DELIMITER  ||
                X.SEGMENT9 || V_DELIMITER  ||
                X.DESCRIPTION || V_DELIMITER  ||
                X.PROYECTO_FA || V_DELIMITER  ||
                X.ASSET_TYPE || V_DELIMITER  ||
                X.ASSET_NUMBER || V_DELIMITER  ||
                X.FECHA_PUESTA_SERVICIO || V_DELIMITER  ||
                X.SERIAL_NUMBER || V_DELIMITER  ||
                X.MODEL_NUMBER || V_DELIMITER  ||
                X.FA_CATEGORY || V_DELIMITER  ||
                X.ASSET_DESCRIPTION || V_DELIMITER  ||
                X.PO_NUMBER || V_DELIMITER  ||
                X.COST || V_DELIMITER  ||
                X.LOCATION_CODE || V_DELIMITER  ||
                X.LOCATION_DESCRIPTION || V_DELIMITER  ||
                X.PERIODO_ADICION || V_DELIMITER;
                
            fnd_file.put_line(fnd_file.output,line);

        end loop;
    exception
        when others then 
            ebuff := 'Error al Main Procedure ' || sqlerrm;
            ECODE := '2';
    end;                                
                                


end XXSV_FA_REPORTS;

