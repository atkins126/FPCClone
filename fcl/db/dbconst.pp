{
    $Id$
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Michael Van Canneyt, member of the
    Free Pascal development team

    Constants used for displaying messages in DB units

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit dbconst;

Interface

Const
  SActiveDataset           = 'Operation cannot be performed on an active dataset';
  SCantSetAutoIncFields    = 'AutoInc Fields are read-only';
  SConnected               = 'Operation cannot be performed on an connected database';
  SDatasetReadOnly         = 'Dataset is read-only.';
  SDatasetRegistered       = 'Dataset already registered : "%s"';
  SDuplicateFieldName      = 'Duplicate fieldname : "%s"';
  SErrAssTransaction       = 'Cannot assign transaction while old transaction active!';
  SErrColumnNotFound       = 'Column "%s" not found.';
  SErrDatabasenAssigned    = 'Database not assigned!';
  SErrNoDatabaseAvailable  = 'Invalid operation: Not attached to database';
  SErrNoSelectStatement    = 'Cannot open a non-select statement';
  SErrNoStatement          = 'SQL statement not set';
  SErrTransactionnSet      = 'Transaction not set';
  SFieldNotFound           = 'Field not found : "%s"';
  SInactiveDataset         = 'Operation cannot be performed on an inactive dataset';
  SInvalidDisplayValues    = '"%s" are not valid boolean displayvalues';
  SInvalidFieldKind        = '%s : invalid field kind : ';
  SInvalidFieldSize        = 'Invalid field size : %d';
  SInvalidTypeConversion   = 'Invalid type conversion to %s in field %s';
  SNeedField               = 'Field %s is required, but not supplied.';
  SNeedFieldName           = 'Field needs a name';
  SNoDataset               = 'No dataset asssigned for field : "%s"';
  SNoDatasetRegistered     = 'No such dataset registered : "%s"';
  SNoDatasets              = 'No datasets are attached to the database';
  SNoSuchRecord            = 'Could not find the requested record.';
  SNoTransactionRegistered = 'No such transaction registered : "%s"';
  SNoTransactions          = 'No transactions are attached to the database';
  SNotABoolean             = '"%s" is not a valid boolean';
  SNotAFloat               = '"%s" is not a valid float';
  SNotAninteger            = '"%s" is not a valid integer';
  SNotConnected            = 'Operation cannot be performed on an disconnected database';
  SNotInEditState          = 'Operation not allowed, dataset "%s" is not in an edit state.';
  SRangeError              = '%f is not between %f and %f for %s';
  SReadOnlyField           = 'Field %s cannot be modified, it is read-only.';
  STransactionRegistered   = 'Transaction already registered : "%s"';
  SUniDirectional          = 'Operation cannot be performed on an unidirectional dataset';
  SUnknownField            = 'No field named "%s" was found in dataset "%s"';
  SUnknownFieldType        = 'Unknown field type : %s';

Implementation

end.  

{
  $Log$
  Revision 1.2  2004-10-16 09:20:25  michael
  + Moved resourcestrings to dbconst

  Revision 1.1  2004/10/10 14:45:51  michael
  + Use of dbconst for resource strings


}
