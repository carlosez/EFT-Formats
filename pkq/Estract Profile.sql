SELECT FVT.FLEX_VALUE_MEANING FROM APPS.FND_FLEX_VALUE_SETS FVS, APPS.FND_FLEX_VALUES FV, APPS.FND_FLEX_VALUES_TL FVT WHERE FVS.FLEX_VALUE_SET_NAME = 'XX_EFT_PROCESS_TYPE' AND FVS.FLEX_VALUE_SET_ID = FV.FLEX_VALUE_SET_ID  AND FV.FLEX_VALUE_ID = FVT.FLEX_VALUE_ID and fv.FLEX_VALUE = 'FINAL' AND FVT.LANGUAGE = userenv('LANG')


SELECT FVT.FLEX_VALUE_MEANING FROM APPS.FND_FLEX_VALUE_SETS FVS, APPS.FND_FLEX_VALUES FV, APPS.FND_FLEX_VALUES_TL FVT WHERE FVS.FLEX_VALUE_SET_NAME = 'XX_EFT_STATUS_CHECK' AND FVS.FLEX_VALUE_SET_ID = FV.FLEX_VALUE_SET_ID  AND FV.FLEX_VALUE_ID = FVT.FLEX_VALUE_ID and fv.FLEX_VALUE = 'NEW' AND FVT.LANGUAGE = userenv('LANG')

select APPLICATION_COLUMN_NAME, dc.*  from 
FND_DESCR_FLEX_COL_USAGE_VL  dc
where 1=1
and END_USER_COLUMN_NAME = 'XX_STATUS_CHECK'
and DESCRIPTIVE_FLEXFIELD_NAME = 'AP_CHECKS'


SELECT TRIM(fnd_profile.value('XX_TIGO_PAIS')) FROM DUAL