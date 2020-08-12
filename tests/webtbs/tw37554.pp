program tw37554;

{$mode objfpc}{$H+}

const
  CmpArray: array[0..88] of Int64 = (
    -1, $FFFFFFFF, -3000000, -2147483648, -131073,

    $FFFFFFFFFFFF0000, $FFFFFFFF0000FFFF, $FFFF0000FFFFFFFF, $0000FFFFFFFFFFFF,

    $FFFFFFFFFFFFFFFE, $FFFFFFFFFFFFFFFD, $FFFFFFFFFFFFFFFB, $FFFFFFFFFFFFFFF7,
    $FFFFFFFFFFFFFFEF, $FFFFFFFFFFFFFFDF, $FFFFFFFFFFFFFFBF, $FFFFFFFFFFFFFF7F,
    $FFFFFFFFFFFFFEFF, $FFFFFFFFFFFFFDFF, $FFFFFFFFFFFFFBFF, $FFFFFFFFFFFFF7FF,
    $FFFFFFFFFFFFEFFF, $FFFFFFFFFFFFDFFF, $FFFFFFFFFFFFBFFF, $FFFFFFFFFFFF7FFF,
    $FFFFFFFFFFFEFFFF, $FFFFFFFFFFFDFFFF, $FFFFFFFFFFFBFFFF, $FFFFFFFFFFF7FFFF,
    $FFFFFFFFFFEFFFFF, $FFFFFFFFFFDFFFFF, $FFFFFFFFFFBFFFFF, $FFFFFFFFFF7FFFFF,
    $FFFFFFFFFEFFFFFF, $FFFFFFFFFDFFFFFF, $FFFFFFFFFBFFFFFF, $FFFFFFFFF7FFFFFF,
    $FFFFFFFFEFFFFFFF, $FFFFFFFFDFFFFFFF, $FFFFFFFFBFFFFFFF, $FFFFFFFF7FFFFFFF,
    $FFFFFFFEFFFFFFFF, $FFFFFFFDFFFFFFFF, $FFFFFFFBFFFFFFFF, $FFFFFFF7FFFFFFFF,
    $FFFFFFEFFFFFFFFF, $FFFFFFDFFFFFFFFF, $FFFFFFBFFFFFFFFF, $FFFFFF7FFFFFFFFF,
    $FFFFFEFFFFFFFFFF, $FFFFFDFFFFFFFFFF, $FFFFFBFFFFFFFFFF, $FFFFF7FFFFFFFFFF,
    $FFFFEFFFFFFFFFFF, $FFFFDFFFFFFFFFFF, $FFFFBFFFFFFFFFFF, $FFFF7FFFFFFFFFFF,
    $FFFEFFFFFFFFFFFF, $FFFDFFFFFFFFFFFF, $FFFBFFFFFFFFFFFF, $FFF7FFFFFFFFFFFF,
    $FFEFFFFFFFFFFFFF, $FFDFFFFFFFFFFFFF, $FFBFFFFFFFFFFFFF, $FF7FFFFFFFFFFFFF,
    $FEFFFFFFFFFFFFFF, $FDFFFFFFFFFFFFFF, $FBFFFFFFFFFFFFFF, $F7FFFFFFFFFFFFFF,
    $EFFFFFFFFFFFFFFF, $DFFFFFFFFFFFFFFF, $BFFFFFFFFFFFFFFF, $7FFFFFFFFFFFFFFF,

    $FFFFFFFFFFFF1234, $FFFFFFFF1234FFFF, $FFFF1234FFFFFFFF, $1234FFFFFFFFFFFF,
    $FFFFFFFF12341234, $FFFF1234FFFF1234, $FFFF12341234FFFF, $FFFF123412341234,
    $FFFFFFFFFFFF0001, $FFFFFFFF0001FFFF, $FFFF0001FFFFFFFF, $0001FFFFFFFFFFFF,

    $0000000100000001, $0000000500000005, $0000AAAA0000AAAA, $0000FFFF0000FFFF
  );

var
  Fail: Boolean;

procedure CompareImmediate(CmpIndex: Integer; TestVal: Int64);
begin
  Write('Test ', CmpIndex, '; input constant: ', TestVal, '; comparing against: ', CmpArray[CmpIndex], ' - ');
  if TestVal = CmpArray[CmpIndex] then
    begin
      WriteLn('Pass');
      Exit;
    end;

  WriteLn('FAIL - expected ', CmpArray[CmpIndex]);
  Fail := True;
end;

begin
  Fail := False;

  CompareImmediate(0, -1);
  CompareImmediate(1, $FFFFFFFF);
  CompareImmediate(2, -3000000);
  CompareImmediate(3, -2147483648);
  CompareImmediate(4, -131073);

  CompareImmediate(5, $FFFFFFFFFFFF0000);
  CompareImmediate(6, $FFFFFFFF0000FFFF);
  CompareImmediate(7, $FFFF0000FFFFFFFF);
  CompareImmediate(8, $0000FFFFFFFFFFFF);

  CompareImmediate(9, $FFFFFFFFFFFFFFFE);
  CompareImmediate(10, $FFFFFFFFFFFFFFFD);
  CompareImmediate(11, $FFFFFFFFFFFFFFFB);
  CompareImmediate(12, $FFFFFFFFFFFFFFF7);

  CompareImmediate(13, $FFFFFFFFFFFFFFEF);
  CompareImmediate(14, $FFFFFFFFFFFFFFDF);
  CompareImmediate(15, $FFFFFFFFFFFFFFBF);
  CompareImmediate(16, $FFFFFFFFFFFFFF7F);

  CompareImmediate(17, $FFFFFFFFFFFFFEFF);
  CompareImmediate(18, $FFFFFFFFFFFFFDFF);
  CompareImmediate(19, $FFFFFFFFFFFFFBFF);
  CompareImmediate(20, $FFFFFFFFFFFFF7FF);

  CompareImmediate(21, $FFFFFFFFFFFFEFFF);
  CompareImmediate(22, $FFFFFFFFFFFFDFFF);
  CompareImmediate(23, $FFFFFFFFFFFFBFFF);
  CompareImmediate(24, $FFFFFFFFFFFF7FFF);

  CompareImmediate(25, $FFFFFFFFFFFEFFFF);
  CompareImmediate(26, $FFFFFFFFFFFDFFFF);
  CompareImmediate(27, $FFFFFFFFFFFBFFFF);
  CompareImmediate(28, $FFFFFFFFFFF7FFFF);

  CompareImmediate(29, $FFFFFFFFFFEFFFFF);
  CompareImmediate(30, $FFFFFFFFFFDFFFFF);
  CompareImmediate(31, $FFFFFFFFFFBFFFFF);
  CompareImmediate(32, $FFFFFFFFFF7FFFFF);

  CompareImmediate(33, $FFFFFFFFFEFFFFFF);
  CompareImmediate(34, $FFFFFFFFFDFFFFFF);
  CompareImmediate(35, $FFFFFFFFFBFFFFFF);
  CompareImmediate(36, $FFFFFFFFF7FFFFFF);

  CompareImmediate(37, $FFFFFFFFEFFFFFFF);
  CompareImmediate(38, $FFFFFFFFDFFFFFFF);
  CompareImmediate(39, $FFFFFFFFBFFFFFFF);
  CompareImmediate(40, $FFFFFFFF7FFFFFFF);

  CompareImmediate(41, $FFFFFFFEFFFFFFFF);
  CompareImmediate(42, $FFFFFFFDFFFFFFFF);
  CompareImmediate(43, $FFFFFFFBFFFFFFFF);
  CompareImmediate(44, $FFFFFFF7FFFFFFFF);

  CompareImmediate(45, $FFFFFFEFFFFFFFFF);
  CompareImmediate(46, $FFFFFFDFFFFFFFFF);
  CompareImmediate(47, $FFFFFFBFFFFFFFFF);
  CompareImmediate(48, $FFFFFF7FFFFFFFFF);

  CompareImmediate(49, $FFFFFEFFFFFFFFFF);
  CompareImmediate(50, $FFFFFDFFFFFFFFFF);
  CompareImmediate(51, $FFFFFBFFFFFFFFFF);
  CompareImmediate(52, $FFFFF7FFFFFFFFFF);

  CompareImmediate(53, $FFFFEFFFFFFFFFFF);
  CompareImmediate(54, $FFFFDFFFFFFFFFFF);
  CompareImmediate(55, $FFFFBFFFFFFFFFFF);
  CompareImmediate(56, $FFFF7FFFFFFFFFFF);

  CompareImmediate(57, $FFFEFFFFFFFFFFFF);
  CompareImmediate(58, $FFFDFFFFFFFFFFFF);
  CompareImmediate(59, $FFFBFFFFFFFFFFFF);
  CompareImmediate(60, $FFF7FFFFFFFFFFFF);

  CompareImmediate(61, $FFEFFFFFFFFFFFFF);
  CompareImmediate(62, $FFDFFFFFFFFFFFFF);
  CompareImmediate(63, $FFBFFFFFFFFFFFFF);
  CompareImmediate(64, $FF7FFFFFFFFFFFFF);

  CompareImmediate(65, $FEFFFFFFFFFFFFFF);
  CompareImmediate(66, $FDFFFFFFFFFFFFFF);
  CompareImmediate(67, $FBFFFFFFFFFFFFFF);
  CompareImmediate(68, $F7FFFFFFFFFFFFFF);

  CompareImmediate(69, $EFFFFFFFFFFFFFFF);
  CompareImmediate(70, $DFFFFFFFFFFFFFFF);
  CompareImmediate(71, $BFFFFFFFFFFFFFFF);
  CompareImmediate(72, $7FFFFFFFFFFFFFFF);

  CompareImmediate(73, $FFFFFFFFFFFF1234);
  CompareImmediate(74, $FFFFFFFF1234FFFF);
  CompareImmediate(75, $FFFF1234FFFFFFFF);
  CompareImmediate(76, $1234FFFFFFFFFFFF);

  CompareImmediate(77, $FFFFFFFF12341234);
  CompareImmediate(78, $FFFF1234FFFF1234);
  CompareImmediate(79, $FFFF12341234FFFF);
  CompareImmediate(80, $FFFF123412341234);

  CompareImmediate(81, $FFFFFFFFFFFF0001);
  CompareImmediate(82, $FFFFFFFF0001FFFF);
  CompareImmediate(83, $FFFF0001FFFFFFFF);
  CompareImmediate(84, $0001FFFFFFFFFFFF);

  CompareImmediate(85, $0000000100000001);
  CompareImmediate(86, $0000000500000005);
  CompareImmediate(87, $0000AAAA0000AAAA);
  CompareImmediate(88, $0000FFFF0000FFFF);

  { Spacing }
  WriteLn('');

  if Fail then
    Halt(1)
  else
    WriteLn('ok');
end.

