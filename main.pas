program summer_practice;
uses GraphWPF, WPFObjects;
uses LAEngine in 'engine/LAEngine.pas';

procedure OnDraw(dt:real);
begin
end;

procedure KeyDown(k: Key);
begin
end;

begin
  
  
  
  OnDrawFrame := OnDraw;
  OnKeyDown := KeyDown;
//  while (true) do begin
//    Redraw(procedure()-> 
//    begin
//       
//    end);
//  end;
end.