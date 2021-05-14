uses GraphABC, ABCObjects;
uses PGUI in '..\..\engine\PGUI.pas';
type ClickHandlerDelegate = procedure(x,y:integer);

var M:PGUIMain;

procedure MouseDown(x, y, mb: integer);
begin
  if (mb = 1) then begin
    M.LeftMouseClick(x,y, false);
    end;
end;

procedure MouseUp(x, y, mb: integer);
begin
  if (mb = 1) then begin
    M.LeftMouseClick(x,y, true);
    end;
end;

begin
  M:= new PGUIMain();
  SetConsoleIO();
  var t := RectangleABC.Create(100, 100, 100, 50);
  var c := M.NewButton(t, procedure() -> begin writeln('Первая кнопка'); end);
  
  t := RectangleABC.Create(400, 100, 100, 100);
  c := M.NewButton(t, procedure() -> begin writeln('Вторая кнопка'); end);
  
  OnMouseDown := MouseDown;
  OnMouseUp := MouseUp;
end.