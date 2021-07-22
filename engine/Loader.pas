//МОДУЛЬ ВСПОМОГАТЕЛЬНЫХ ФУНКЦИЙ
unit Loader;
uses System, System.IO, System.Diagnostics;

///Устанавливаем шрифты программы
procedure LoadFont();
begin
  //var fonts:array of string := new string[0];
  var fonts:array of string := ('GranaPadano');
  if (fonts.Length = 0) then exit;
  for var i := 0 to fonts.Length-1 do
    if not System.IO.File.Exists('C:\Windows\Fonts\'+fonts[i]+'.ttf') then begin
      System.IO.File.Copy('fonts\'+fonts[i]+'.ttf', 'C:\Windows\Fonts\'+fonts[i]+'.ttf');
      var info := new ProcessStartInfo('engine\FontReg.exe', '/copy');
      info.UseShellExecute := true;
      info.WindowStyle := ProcessWindowStyle.Hidden;
      info.Verb := 'runas';
      System.Diagnostics.Process.Start(info);
      writeln('Шрифт ', fonts[i] ,' загружен и установлен!');
    end;
end;

initialization
LoadFont();
end.