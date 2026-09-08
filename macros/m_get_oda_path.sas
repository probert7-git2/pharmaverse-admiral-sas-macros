/*--------------------------------------------------------------
  Program Name                : m_get_oda_path.sas
  Purpose                     : Build ODA paths as /home/&sysuserid/&relpath
  Usage                       : %let PVA_SAS_ROOT=%m_get_oda_path(SAS_mirrored_Admiral_safety_ADaM/SAS);
  Note                        : ODA does not allow HOME or ~ - use this helper.
  Modification Log            : 21AUG2026 - Initial from user get_oda_path helper.
--------------------------------------------------------------*/

%macro m_get_oda_path(relpath);
  %local full;
  %let full = /home/&sysuserid/&relpath;
  &full
%mend m_get_oda_path;
