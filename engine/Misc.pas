//МОДУЛЬ ВСПОМОГАТЕЛЬНЫХ ФУНКЦИЙ
unit Misc;
uses System, System.IO, System.Diagnostics;
uses GraphWPF, WPFObjects, Timers;


///Проверяет - принадлежит ли точка прямоугольнику объекта
function PtInside(x,y:real; obj:ObjectWPF):boolean;
begin
  if (x>obj.LeftTop.X) and (x<obj.RightTop.X) and (y>obj.LeftTop.Y) and (y<obj.RightBottom.Y) then
  Result:=True;
end;

///Меняет изображение from на изображение из файла по пути too.
procedure ChangePicture(var from:PictureWPF; too:string);
begin
  var p := from;
  from := new PictureWPF(p.LeftTop, too);
  p.Destroy();
end;

///Умножает цвет объекта на mult, делая его ярче/темнее.
procedure Tint(var obj:ObjectWPF; mult:real);
begin
  var c := obj.Color;
  var R := round(c.R*mult); if R>255 then R:= 255 else if R<0 then R := 0;
  var G := round(c.G*mult); if G>255 then G:= 255 else if G<0 then G := 0;
  var B := round(c.B*mult); if B>255 then B:= 255 else if B<0 then B := 0;
  obj.Color := ARGB(255, R, G, B);  
end;

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
      info.UseShellExecute := false;
      info.WindowStyle := ProcessWindowStyle.Hidden;
      System.Diagnostics.Process.Start(info);
      writeln('Шрифт ', fonts[i] ,' загружен и установлен!');
    end;
end;

initialization
LoadFont();
end.