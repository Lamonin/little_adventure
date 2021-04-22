library Vector2;

type
V2 = class
  private
  
  //Возвращает нормализованный вектор
  function Normalize():V2;
  begin
    var v2n := new V2(0,0);
    var l := sqrt(sqr(x) + sqr(y));
    if l<>0 then begin
      v2n.x := round(1/l * x, 3); v2n.y := round(1/l * y, 3);
    end;
    result:= v2n;
  end;
  
  //Возвращает длину вектора
  function Length():real;
  begin
    result:= round(sqrt(sqr(x) + sqr(y)),3);
  end;
  
  //Возвращает вектор с целочисленными X и Y
  function PositionRound():V2;
  begin
    result := new V2();
    result.x := round(x);
    result.y := round(y);
  end;
  
  public
  x,y:real;
  
  constructor ();
  begin
    x:=0; y:=0;
  end;
  
  constructor (xt,yt:real);
  begin
    x:=xt; y:=yt;
  end;
  
  //Сумма двух векторов = новый Vector2
  static function operator+(v21, v22:V2):V2;
  begin
    result := new V2();
    result.x := v21.x + v22.x;
    result.y := v21.y + v22.y;
  end;
  
  //Вычитание двух векторов = новый Vector2
  static function operator-(v21, v22:V2):V2;
  begin
    result := new V2();
    result.x := v21.x - v22.x;
    result.y := v21.y - v22.y;
  end;
  
  //Умножение вектора на скаляр (число)
  static function operator*(v21:V2; n:real):V2;
  begin
    result := new V2();
    result.x := v21.x*n;
    result.y := v21.y*n;
  end;
  
  property normalized: V2 read Normalize;
  property magnitude: real read Length;
  property posInt: V2 read PositionRound;
end;

end.