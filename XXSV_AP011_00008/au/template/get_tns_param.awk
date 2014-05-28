#/*=========================================================================+
#|  Copyright (c) 2012 Oratechla, San Salvador, El Salvador                 |
#|                         ALL rights reserved.                             |
#+==========================================================================+
#|                                                                          |
#| FILENAME                                                                 |
#|     XXXBOL_INV01_00001_ALL.sh                                            |
#|                                                                          |
#| DESCRIPTION                                                              |
#|    Shell Script para Proyecto TIGO                                       |
#|                                                                          |
#| SOURCE CONTROL                                                           |
#|    Version: %I%                                                          |
#|    Fecha  : %E% %U%                                                      |
#|                                                                          |
#| HISTORY                                                                  |
#|    06-Sep-2012  E.Monsalve     Created   Oratechla                       |
#+==========================================================================*/
# TNS Parameter extract program
{
   line = toupper($0)
   start_idx = index(line, toupper(tns_token))
   if (start_idx > 0)
   {
      prefix = substr(line, start_idx)
      end_idx = index(prefix, ")")
      print(substr(prefix, length(tns_token) + 2, end_idx - length(tns_token) - 2))
   }
}