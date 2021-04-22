{Модуль содержит основные переменные игры и функции}
{$reference Vector2.dll}
unit LAEngine;
uses GraphABC, ABCObjects;

type
  Entity = class
    private
    position : V2 = new V2();
    w,h:integer;
    speed:integer;
    hitpoint:integer;
    
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
    
    constructor Create(x,y,wt,ht, hp, spd:integer);
    begin
      w:=wt; h:=ht; hitpoint:=hp; speed:=spd;
      position.x := x; position.y:=y;
    end;
    
    procedure MoveOn(v:V2);
    begin
      
    end;
    
    property pos:V2 read getPos write setPos;
  end;
  
  Player = class(Entity)
    private
    
    public
    constructor Create(x,y,w,h, hp, speed:integer; pathToSprite:string);
    begin
      inherited Create(x, y, w, h, hp, speed);
      obj := RectangleABC.Create(x - w div 2, y-h div 2, w, h, clRed);
    end;
    
  end;
  
  //Класс объекта для взаимодействия с ним
  Prop = class
    private
    positon : V2 := new V2();
    
    public
    obj : ObjectABC;
    
    constructor Create();
    begin
      
    end;
  end;
end.