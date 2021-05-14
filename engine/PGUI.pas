unit PGUI;
uses ABCObjects;

type
  tProc = procedure();

  {КНОПКА}
  Button = class
    private
    hasClicked:boolean;
    obj:ObjectABC;
    event event_button : procedure;
    
    procedure ProcessEvents;
    begin
      if (event_button<>nil) then event_button;
    end;
    
    public
    
    constructor Create(obj:ObjectABC; e:tProc := nil);
    begin
      self.obj := obj;
      if (e <> nil) then
        self.event_button += e;
    end;
    
    procedure SetSize(w,h:integer);
    begin
      obj.Width := w;
      obj.Height := h;
    end;
    
    //Добавляет событие к кнопке
    procedure AddEvent(e:tProc);
    begin
      event_button += e;
    end;
    
    //Полезность нам под вопросом
    procedure RemoveEvent(e:tProc);
    begin
      event_button -= e;
    end;
    
    //Проверяет нажата ли кнопка
    procedure CheckButton(x,y:integer; isUp:boolean);
    begin
      if (obj.PtInside(x,y)) and not isUp then begin
        obj.Color := Color.Gray;
        hasClicked := true;
      end
      else if (isUp) and hasClicked then begin
        if obj.PtInside(x,y) then
          ProcessEvents;
        hasClicked := false;
        obj.Color := Color.White;
      end;
    end;
  end;
  
  HorizontalPanel = class
    private
    x, y, height:integer;
    childrens:List<ObjectABC>;
    
    procedure DistributeChildrens();
     var x_offset, y_offset:integer;
    begin
      x_offset := self.x;
      y_offset := self.y;
      
      foreach var t in childrens do begin
        t.Position.X := x_offset;
        t.Position.Y := y_offset;
        x_offset += t.Width;
      end;
    end;
    
    public
    constructor Create(x, y, h:integer);
    begin
      height := h;
      self.x:=x;
      self.y:=y;
      
      childrens := new List<ObjectABC>();
    end;
    
    procedure AddChild(child:ObjectABC);
    begin
      child.Height := height;
      childrens.Add(child);
      DistributeChildrens();
    end;

  end;

  {ГЛАВНЫЙ КОМПОНЕНТ GUI}
  PGUIMain = class
    private
    
    public
    event LMouseClickEvent:procedure(x,y:integer; t:boolean);
    
    constructor Create();
    begin
      
    end;
    
    //Создает из объекта obj - новую кнопку, при нажатии на которую
    //срабатывает процедура e
    function NewButton(obj:ObjectABC; e:tProc):Button;
    begin
      Result := new Button(obj, e);
      LMouseClickEvent += Result.CheckButton;
    end;
    
    //При вызове вызывает все методы, которые были
    //привязанны к обработчику LMouseClickEvent
    procedure LeftMouseClick(x,y:integer; t:boolean);
    begin
      if LMouseClickEvent<>nil then LMouseClickEvent(x,y,t);
    end;
  end;
end.