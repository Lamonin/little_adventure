{Модуль содержит основные переменные игры и функции}
{$reference Vector2.dll}
unit LAEngine;
uses GraphABC, ABCObjects;

type
  Mover = class
    private
    position : V2;
    w,h:integer;
    
    //Устанавливает позицию Mover и смещает графическое представление
    //по целочисленным координатам
    procedure setPos(v:V2);
    begin
      position := v;
      obj.MoveTo(round(position.x - w div 2), round(position.y-h div 2));
    end;
    
    //Возвращает позицию Mover
    function getPos():V2;
    begin
      Result := position;
    end;
    
    public
    obj:ObjectABC;
    
    constructor Create(x,y,wt,ht:integer);
    begin
      w:=wt; h:=ht;
      obj := RectangleABC.Create(x - w div 2, y-h div 2, w, h, clRed);
      position.x := x; position.y:=y;
    end;
    
    property pos:V2 read getPos write setPos;
  end;
  
  Player = class(Mover)
    private
    
    public
    constructor Create(x,y,w,h:integer; pathToSprite:string);
    begin
      inherited Create(x,y,w,h);
    end;
    
  end;
end.