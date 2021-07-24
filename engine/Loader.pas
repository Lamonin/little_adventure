//МОДУЛЬ ВСПОМОГАТЕЛЬНЫХ ФУНКЦИЙ
unit Loader;
uses System, System.IO, System.Diagnostics;

///Устанавливаем шрифты программы
procedure LoadFont();
begin
  var fonts:array of string := ('GranaPadano');
  if (fonts.Length = 0) then exit;
  for var i := 0 to fonts.Length-1 do
    if not System.IO.File.Exists('C:\Windows\Fonts\'+fonts[i]+'.ttf') then begin
      try 
        System.IO.File.Copy('fonts\'+fonts[i]+'.ttf', 'C:\Windows\Fonts\'+fonts[i]+'.ttf');
      except
        writeln('Шрифт не установлен! Ошибка!');
        writeln('Пожалуйста, установите из папки fonts шрифт GranaPadano.ttf и запустите игру заново!');
        exit;
      end;
      
      var info := new ProcessStartInfo('engine\FontReg.exe', '/copy');
      info.UseShellExecute := true;
      info.WindowStyle := ProcessWindowStyle.Hidden;
      System.Diagnostics.Process.Start(info);
      writeln('Шрифт ', fonts[i] ,' загружен и установлен!');
    end;
end;

initialization
  LoadFont();
end.