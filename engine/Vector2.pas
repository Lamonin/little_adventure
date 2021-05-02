library Vector2;

type
V2 = class
  private
  //Возвращает длину вектора
  function Length():real;
  begin
    result:= round(sqrt(sqr(x) + sqr(y)), 3);
  end;
  
  public
  x,y:integer;
  
  constructor ();
  begin
    x:=0; y:=0;
  end;
  
  constructor (xt,yt:integer);
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
  static function operator*(v21:V2; n:integer):V2;
  begin
    result := new V2();
    result.x := v21.x*n;
    result.y := v21.y*n;
  end;
  
  //Возвращает вектор схожий по направлению длины length
  function NMultiple(length:integer):V2;
  begin
    result := new V2();
    var l := Self.magnitude;
    if l<>0 then begin
      result.x := round(round(1/l * x, 3) * length);
      result.y := round(round(1/l * y, 3) * length);
    end;
  end;
  
  property magnitude: real read Length;
end;

end.