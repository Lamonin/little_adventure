unit LAEngine;
{$reference Newtonsoft.Json.dll}
uses Newtonsoft.Json.Linq, WPFObjects, Timers, Loader;

//###Вспомогательные методы для работы
type delegate = procedure;
///Выполняет действие p с через время delay
procedure DelayAction(delay:integer; const p:delegate);
begin
  var t : Timer; t := new Timer(delay, procedure -> begin p(); t.Stop();
  end); t.Start();
end;
///Проверяет - принадлежит ли точка прямоугольнику объекта
function PtInside(x,y:real; obj:ObjectWPF):boolean;
begin
  Result:=(x>obj.LeftTop.X) and (x<obj.RightTop.X) and (y>obj.LeftTop.Y) and (y<obj.RightBottom.Y);
end;

///Меняет изображение from на изображение из файла по пути too.
procedure ChangePicture(var from:PictureWPF; path:string);
begin var p := from; from := new PictureWPF(p.LeftTop, path); p.Destroy(); end;

function ChangePicture(var from, too:PictureWPF):PictureWPF;
begin
  if (from = nil) or (too = nil) then exit;
  from.Visible := false;
  too.Visible := true;
  Result := too;
end;

function ApplyFontSettings(const obj:ObjectWPF):ObjectWPF;
begin
  obj.SetText(obj.Text, 32, 'GranaPadano', ARGB(255, 255, 214, 0));
  obj.TextAlignment := Alignment.Center;
  Result := obj;
end;
//###---------------------------------------------

//Опережающее описание процедур
procedure CloseLevel(); forward;
procedure ChangeLevel(lname:string); forward;
procedure DrawMainMenu(); forward;

type
  //##############-ВСПОМОГАТЕЛЬНЫЙ_БЛОК-################
  ///Получение и изменение значений в файле JSON формата.
  LALoader = class
    private
    path:string; jObj:JObject; //Хранит весь наш файл для дальнейшней работы с ним
    public
    ///Говорим "обрабатывать" файл с JSON структурой по пути path
    constructor Create(path:string);
    begin
      self.path := path;
      //Загружаем текстовый файл и преобразуем в структуру JSON.NET библиотеки
      jObj := JObject.Parse(ReadAllText(path, Encoding.UTF8));
    end;
    
    ///Получаем значение по пути ключей. Где TL - необходимо указать тип значения.
    ///Например: GetValue&<integer>('enemy.zombie.hp'); //знак & - тоже обязателен.
    function GetValue<TL>(key:String):TL;
    begin
      key := '$.' + key;
      var token := jObj.SelectToken(key);
      if (token = nil) then writeln('Такого ключа не существует!')
      else Result := token.ToObject&<TL>();
    end;
    
    ///Устанавливает значение val по пути key в файле json,
    ///если такой путь существует!
    ///Например: SetValue('enemy.zombie.hp', 100);
    procedure SetValue<TL>(key:string; val:TL);
    begin
      key := '$.' + key;
      var v := JToken.FromObject(val as Object);
      var token := jObj.SelectToken(key);
      if (token = nil) then writeln('Такого ключа ', key, ' не существует!')
      else token.Replace(v);
    end;
    
    ///Сохраняет изменения в файле
    procedure SaveFile() := WriteAllText(path, jObj.ToString(), Encoding.UTF8);
  end;

  Button = class
    private
    pic, idle, click:PictureWPF; 
    isClicked:boolean;
    isActive:boolean:=True;
    idlePic, clickPic, buttonText:string;
    hoverPic:RectangleWPF;
    
    procedure Hover(x, y: real; mousebutton: integer);
    begin
      if isClicked or not isActive then exit;
      if (PtInside(x,y,pic)) then
        hoverPic.Visible := True
      else
        hoverPic.Visible := False;
    end;
    
    ///Изменение спрайта на clickPic
    procedure Clicked(x, y: real; mousebutton: integer);
    begin
      if (pic = nil) or not isActive then exit;
      if (mousebutton <> 1) and (isClicked) then exit;
      if PtInside(x,y,pic) then begin 
        isClicked := True;
        pic := ChangePicture(pic, click); ApplyText();
      end;
    end;
    
    ///Обработка нажатия
    procedure Process(x, y: real; mousebutton: integer);
    begin
      if (pic = nil) or not isActive then exit;
      pic := ChangePicture(pic, idle); ApplyText();
      if (mousebutton <> 0) then exit;
      if (OnClick <> nil) and PtInside(x,y,pic) and (isClicked) then OnClick();
      isClicked := False;
    end;
    
    procedure ApplyText();
    begin
      if (buttonText = '') or (pic = nil) then exit;
      pic.Text := buttonText;
      pic := ApplyFontSettings(pic) as PictureWPF;
    end;

    procedure SetActive(t:boolean);
    begin
      isActive := t; var ts:= click;
      if t then ts:= idle
      else hoverPic.Visible := False;
      pic := ChangePicture(pic, ts); ApplyText();
    end;
    
    procedure SetText(t:string);
    begin buttonText := t; ApplyText(); end;
    
    public
    //Событие нажатия на кнопку
    event OnClick: procedure;

    ///Создаем кнопку с изображением по умолчанию idlePic
    ///И с изображением по нажатию clickPic.
    constructor Create(x,y:integer; idlePic, clickPic:string);
    begin
      self.idlePic := 'img\ui\' + idlePic;
      self.clickPic := 'img\ui\' + clickPic;
      
      idle := new PictureWPF(x, y, self.idlePic);
      click := new PictureWPF(x,y, self.clickPic);
      click.Visible := False;
      pic := idle;
      hoverPic := new RectangleWPF(x,y,pic.Width, pic.Height, Colors.Transparent, 4, ARGB(255, 255, 214, 0));
      hoverPic.Visible := false;
      OnMouseDown += Clicked; OnMouseUp += Process;
      OnMouseMove += Hover;
    end;

    constructor Create(x,y:integer; text, idlePic, clickPic:string);
    begin
      Create(x,y, idlePic, clickPic);
      Self.Text := text;
      ApplyText();
    end;
    
    procedure Destroy();
    begin
      OnMouseDown -= Clicked; OnMouseUp -= Process;
      OnMouseMove -= Hover;
      if (pic = nil) then exit;
      hoverPic.Destroy();
      pic.Destroy(); pic := nil;
    end;
    
    property Text: string read buttonText write SetText;
    property Active: boolean read isActive write SetActive;
  end;
  
  spriteInfo=record
    frames:array of PictureWPF; //Кадры анимации.
    speed:integer; //Скорость анимации.
    isLoop:boolean; //Зациклена ли анимация.
    AnimProcedure:procedure; //Имеет смысл только если анимация не зациклена.
  end;
  
  LSprite = class
    private
    anims:Dictionary<string, spriteInfo>; //Все анимации по их именам
    curAnim:spriteInfo; //Текущая анимация
    sprite: PictureWPF;
    position:Point;
    updater:Timer;
    frameNum:Integer; //Номер текущего кадра анимации.
    enabledFrame:integer := -1; //Номер текущего включенного кадра.
    isVisible:boolean := True; //По инициализации спрайт видим.
    
    procedure ChangeSprite();
    begin
      Redraw(procedure -> begin
        if sprite <> nil then sprite.Visible := false;
        sprite := curAnim.frames[frameNum];
        sprite.Visible := true and isVisible;
        sprite := sprite;
        var p := position; p.x += 24;
        sprite.Center:=p;
      end);
    end;
    
    //Обновление кадра изображения
    procedure UpdateFrame();
    begin
      if (frameNum<curAnim.frames.Length-1) then begin frameNum+=1; ChangeSprite(); end
      else if curAnim.isLoop then begin frameNum:=0; ChangeSprite(); end
      else begin updater.Stop(); curAnim.AnimProcedure() end;
    end;

    function GetPos():Point;
    begin
      if (sprite<>nil) then Result := sprite.Center
      else Result := position;
    end;
    
    ///Устанавливает позицию спрайта
    procedure SetPos(pos:Point);
    begin
      position := pos; pos.X += 24; 
      if sprite<>nil then sprite.Center := pos;
    end;

    function GetWidth():integer;
    begin
      if sprite<>nil then
        Result := floor(sprite.Width)
      else writeln('Ширина спрайта не может быть получена!');
    end;

    function GetHeight():integer;
    begin
      if sprite<>nil then
        Result := floor(sprite.Height)
      else writeln('Высота спрайта не может быть получена!');
    end;

    public
    ///Конструктор с инициализацией стандартной анимации с обычными параметрами
    constructor Create(x,y:integer; aname:string; frames:array of PictureWPF);
    begin
      Create(x,y,aname, frames, 160, True);
    end;
    
    ///Конструктор с инициализацией стандартной анимации
    constructor Create(x,y:integer; aname:string; frames:array of PictureWPF; speed:integer; looped:boolean);
    begin
      position.x := x * 48; position.y := y * 48;     
      anims := new Dictionary<string, spriteInfo>();
      AddAnim(aname, frames, speed, looped);
      updater := new Timer(100,UpdateFrame);
      SetPos(position);
    end;
   
    ///Принадлежит ли точка спрайту
    function PtInside(x,y:Real):boolean; begin
    result := LAEngine.PtInside(X,Y,curAnim.frames[frameNum]); end;
    
    ///Добавляет новую анимацию с именем aname
    procedure AddAnim(aname:string; frames:array of PictureWPF; speed:integer; looped:boolean; AnimProcedure:procedure:=nil);
    begin
      var frame:spriteInfo;
      frame.frames:= frames; frame.speed:=speed; frame.isLoop:=looped; frame.AnimProcedure:= AnimProcedure;
      anims.Add(aname, frame);
    end;
    
    ///Проигрывает анимацию с именем aname
    procedure PlayAnim(aname:string);
    begin
      updater.Stop();
      curAnim := anims[aname]; frameNum := 0;
      updater.Interval := curAnim.speed;
      updater.Start();
      ChangeSprite();
    end;
    
    ///Уничтожаем спрайт.
    procedure Destroy();
    begin
      foreach var a in anims.Values do begin
        foreach var t in a.frames do 
          t.Destroy();
        a.frames := nil;
      end;
      anims.Clear(); anims := nil;
      sprite := nil;
    end;
    property Pos: Point Read GetPos write SetPos;
		///Видимость спрайта
    property Visible: boolean write isVisible read isVisible;
    property Width: integer read GetWidth;
    property Height: integer read GetHeight;
  end;
  
  ///Загружает спрайт с именем sname.
  function LoadSprite(sname:string):array of PictureWPF;
  begin
    Result := new PictureWPF[1]; Result[0] := new PictureWPF(0,0,'img/'+sname+'.png');
    Result[0].Visible := false;
  end;
  
  ///Загружает последовательность спрайтов с именем sname и номерами от 1 до count.
  function LoadSprites(sname:string; count:integer):array of PictureWPF;
  begin
    var t := new PictureWPF[count];
    Redraw(procedure -> begin
      for var i:= 0 to count-1 do begin 
        t[i] := new PictureWPF(0,0,'img/'+sname+(i+1)+'.png');
        t[i].Visible := false;
      end;
    end);
    Result := t;
  end;
  //##############-КОНЕЦ_ВСПОМОГАТЕЛЬНЫЙ_БЛОК-################
  
  //ИГРОВЫЕ СОБЫТИЯ
  var OnPlayerMove: procedure(x,y:integer);
      OnEnterBattle: procedure;
      OnExitBattle: procedure;

  type
  Transition = class
    private
    static pic:RectangleWPF;
    static proc:delegate;
    public
    static constructor();
    begin
      pic := new RectangleWPF(0, 0, 1296, 768, Colors.Black);
      pic := ApplyFontSettings(pic) as RectangleWPF; pic.Visible := False;
      OnDrawFrame += procedure(dt:real) -> ToFront();
    end;
    
    ///Показать изображение перехода
    static procedure Show(delay:integer; p:delegate:=nil) := Show('Загрузка уровня...', delay, p);
    
    ///Показать изображение перехода с нужным текстом после загрузки
    static procedure Show(message:string; delay:integer; p:delegate:=nil);
    begin
      (pic.Visible, pic.Text) := (True, message);
      proc:=p;
      DelayAction(delay, procedure -> Hide());
    end;
    
    ///Скрыть изображение перехода
    static procedure Hide();
    begin
      if (proc<>nil) then proc;
      pic.Visible := False;
    end;
    
    static procedure ToFront();
    begin if (pic <> nil) then pic.ToFront() end;
  end;

  DialogHandler = class
    private
    static messages : array of string;
    static messageNum, messageCount:integer; //Текущий номер сообщения и текущий символ сообщения
    static messageTimer:Timer;
    static dialogRect:PictureWPF;
    static isDialogue: boolean; //Идёт ли диалог
    
    static procedure EndDialogue();
    begin
      dialogRect.Visible := False;
      messageTimer.Stop(); isDialogue := False;
    end;
    public
    static constructor();
    begin
      Redraw(procedure() -> begin
        dialogRect := new PictureWPF(0,768-128,'img\ui\rect_game_big.png');
        dialogRect := ApplyFontSettings(dialogRect) as PictureWPF;
        dialogRect.FontSize := 24;
        dialogRect.Visible := False;
      end);
      messageTimer := new Timer(16, procedure() -> begin
        dialogRect.Text += messages[messageNum][messageCount];
        if (messageCount = messages[messageNum].Length) then
          messageTimer.Stop();
        messageCount += 1;
      end);
    end;

    static procedure StartDialog(msgs:array of string);
    begin
      dialogRect.ToFront();
      (messageNum, messageCount, messages, isDialogue) := (-1, 1, msgs, True);
      dialogRect.Visible := True;
      NextMessage();
    end;

    static function NextMessage():boolean;
    begin
      if not isDialogue then exit;
      Result:=True; //Диалог может продолжаться
      if (messageTimer.Enabled) then
      begin
        messageTimer.Stop(); dialogRect.Text := messages[messageNum]; exit;
      end;
      messageNum += 1;

      //Если показали все сообщения, то закрываем окно диалога.
      if (messageNum = messages.Length) then begin
        EndDialogue(); exit;
      end;
      //Начинаем с первого символа сообщения и пустого текста в окне сообщений
      messageCount := 1; dialogRect.Text := '';
      messageTimer.Start();
    end;
    
    static property isInDialogue:boolean read isDialogue;
  end;
  BattleEntity = class
    private
    hp, attackDmg, agility, actionPoint, delay : integer;
    isDeath:boolean;
    public
    constructor Create(); begin end;
     
    function AddAction():boolean;
    begin
      if isDeath then exit;
      actionPoint+= agility;
      if actionPoint >=10 then 
      begin
        actionPoint-=10;
        result:= True;
      end;
    end;
    
    procedure Destroy(); virtual; begin end;
    procedure Damage(Dmg: integer);virtual; begin end;
    procedure Attack(E:BattleEntity);virtual; begin end;
    
    property GetDelay: integer Read delay;
    property GetHP:integer Read hp;
    end;
  
  Enemy = class(BattleEntity)
    private
    name:string;
    Sprite : LSprite;
    LockThis, isDeath: boolean; //Выбран ли этот враг || Убит ли этот враг
    CirclePic, ShadowPic: PictureWPF; //Круг выделения и тень
    ///Нажатие на врага в бою
    procedure klik(x, y: real; mb: integer);
    begin
      if (Sprite <> nil) and (mb=1) and (Sprite.PtInside(x,y)) and not (LockThis) then 
      begin Select(); end;
    end;

    procedure Death();
    begin
      isDeath := True;
      OnMouseDown -= klik;
      Sprite.PlayAnim('Death');
    end;
    
    function GetCircle():PictureWPF;
    begin
      if (CirclePic<>nil) then Result := CirclePic;
    end;

    public
    static SelectedEnemy: Enemy;
    constructor Create(x,y:integer);
    begin
      OnMouseDown += klik;
    end;

    procedure CreateCircleShadowPics();
    begin
      Redraw(procedure -> begin 
        ShadowPic := new PictureWPF(0,0, 'img\enemy\shadow.png');
        ShadowPic.Visible := False;
        CirclePic:= new PictureWPF(0,0,'img\enemy\circle.png');
        CirclePic.Visible := False;
      end);
    end;

    procedure MoveCircleShadowPics(yOffset:integer);
    begin
      Redraw(procedure -> begin 
        var sp := Sprite.Pos;
        ShadowPic.MoveTo(sp.X-65, sp.Y+Sprite.Height/2-yOffset);
        ShadowPic.Visible := True;
        CirclePic.MoveTo(sp.X-65, sp.Y+Sprite.Height/2-45);
        CirclePic.Visible := False;
      end);
    end;

    procedure Select();
    begin
      if (SelectedEnemy<>nil) then 
        SelectedEnemy.Deselect();
      CirclePic.Visible := True; LockThis:= True;
      SelectedEnemy:= self;
    end;

    procedure Deselect();
    begin
      SelectedEnemy.GetCirclePic.Visible := False;    
      SelectedEnemy.SetLockThis:= False;
      SelectedEnemy := nil;
    end;

    procedure Attack(E:BattleEntity); override;
    begin
      if (isDeath) or (E.GetHP <= 0) then exit;
      E.Damage(attackDmg);
      Sprite.PlayAnim('Attack');
    end;
    
    procedure Damage(Dmg: integer); override;
    begin
      hp -= Dmg; if (hp<=0) then Death() else Sprite.PlayAnim('Hit');
    end;

    procedure Destroy(); override;
    begin
      if (Sprite<>nil) then Sprite.Destroy(); Sprite := nil;
      if (ShadowPic<>nil) then ShadowPic.Destroy(); ShadowPic := nil;
      if (CirclePic<>nil) then CirclePic.Destroy(); CirclePic := nil;
    end;
    
    property GetName: string read name;
    property GetCirclePic: PictureWPF read GetCircle;
    property GetDeath: boolean Read isDeath;
    property SetLockThis: boolean write LockThis;
    end;
  
  SkeletonEnemy = class(Enemy)
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      (name, hp, attackDmg, agility, Delay) := ('СКЕЛЕТОН', 9, 5, 3, 2000);
      CreateCircleShadowPics();
      Sprite:= new LSprite(x,y,'Idle',LoadSprites('enemy\Skeleton\idle', 6));
      Sprite.AddAnim('Hit', LoadSprites('enemy\Skeleton\hit', 4), 160, False, procedure()->
        Sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Attack', LoadSprites('enemy\Skeleton\attack', 10), 160, False, procedure()->
      sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Death', LoadSprites('enemy\Skeleton\death', 5), 160, False);
      Sprite.PlayAnim('Idle');
      MoveCircleShadowPics(40);
    end;
    end;
  
  TreeEnemy = class(Enemy)
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      (name, hp, attackDmg, agility, Delay) := ('ДРЕВО', 15, 4, 2, 2000);
      CreateCircleShadowPics();
      Sprite:= new LSprite(x,y,'Idle',LoadSprites('enemy\Sprout\idle', 4));
      Sprite.AddAnim('Hit', LoadSprites('enemy\Sprout\hit', 5), 160, False, procedure()->
        Sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Attack', LoadSprites('enemy\Sprout\attack', 6), 160, False, procedure()->
        Sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Death', LoadSprites('enemy\Sprout\death', 8), 160, False);
      Sprite.PlayAnim('Idle');
      MoveCircleShadowPics(45);
    end;
    end;
  
  GolemEnemy = class(Enemy)
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      (name, hp, attackDmg, agility, Delay) := ('ГОЛЕМ <БОСС>', 30, 10, 8, 2000);
      CreateCircleShadowPics();
      Sprite:= new LSprite(x, y, 'Idle', LoadSprites('enemy\Golem\idle', 6), 120, True);
      Sprite.AddAnim('Hit', LoadSprites('enemy\Golem\hit', 4), 120, False, procedure()->
        sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Attack', LoadSprites('enemy\Golem\attack', 8), 120, False, procedure()->
        Sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Death', LoadSprites('enemy\Golem\death', 10), 120, False);
      Sprite.PlayAnim('Idle'); //Включаем как анимацию по умолчанию
      MoveCircleShadowPics(45);
    end;
    end;
  
  BattlePlayer = class(BattleEntity)
    private
    max_hp, armor:integer; //Максимальное здоровье и броня игрока
    public
    constructor Create();
    begin
      var loader := new LALoader('data/userdata.json');
      max_hp:= loader.GetValue&<integer>('max_hp');;
      hp:= loader.GetValue&<integer>('hp');
      armor:= loader.GetValue&<integer>('armor');
      attackDmg:= 8;
      agility:= 5;
      Delay:= 250;
    end;
    
    procedure Attack(E:BattleEntity);override;   
    begin
      if (E = nil) then exit; 
      E.Damage(AttackDmg);
    end;

    procedure AddHP(val:integer);
    begin
      hp += val;
      if hp>max_hp then hp := max_hp;
    end;
        
    procedure Damage(Dmg: integer);override;
    begin
      Dmg -= armor; if Dmg<=0 then Dmg := 1;
      hp -= Dmg; if (hp<=0) then hp := 0;
    end;
    
    property GetHP: integer Read hp;
    property GetMaxHP: integer Read max_hp;
    property GetDamage: integer Read attackDmg;
    property SetGetArmor: integer Read armor Write armor;
    end;
  
  UseObject = class
    public
    procedure Use(); virtual; begin end;
    procedure Destroy(); virtual; begin end;
  end;
  levelGridRecord = record
    CantGet:boolean; //Можно ли ступить на клетку
    GridObject:UseObject; //Объект на клетке
  end;
  
  levelGrid = array[0..15, 0..26] of levelGridRecord;
  ///Общие данные игры по ходу её выполнения.
  var 
      Grid: levelGrid;
      LevelPic, CombatPic, BgPic:PictureWPF;
      BPlayer: BattlePlayer; //Сущность игрока в бою.
  type
  BattleHandler = class
    private
    static ProcessTimer: Timer;
    static StopTimer, isPlayerTurn: boolean;
    static EnemyPanel, DamagePanel, ArmorPanel, HpPanel, TurnRect : PictureWPF;
    static b_attack, b_run: Button;
    static CombatTimer: Timer;
    static enemyCount: integer;
    static EnemyList: List<Enemy>;
    static x,y:integer;

    static procedure CreateEnemy(const enemyName:string; X,Y:integer);
    begin
      var E: Enemy;
      case enemyName of
        'Skeleton': E:= new SkeletonEnemy(X,Y);
        'TreeEnemy': E:= new TreeEnemy(X,Y);
        'Golem': E:= new GolemEnemy(X,Y);
      end; EnemyList.Add(E);
      enemyCount += 1;
    end;

    //Обработка очереди действий сущностей
    static procedure ProcessAttack(ActionList: List<BattleEntity>);
    begin
    var i:= 0;
    ProcessTimer := new Timer(100, procedure() -> begin 
      if isPlayerTurn then exit;
      if i = ActionList.Count then begin
        ProcessTimer.Stop(); Stoptimer:=False; exit;
      end;
      ProcessTimer.Interval:= ActionList[i].GetDelay;
      //Ходит игрок
      if ActionList[i] is BattlePlayer then begin 
        isPlayerTurn:= True; 
        TurnRect.Text := 'ВАШ ХОД'; i+=1;
        b_attack.Active := True;
        b_run.Active := True;
        exit; 
      end;
      TurnRect.Text := 'ХОД ПРОТИВНИКА';
      b_attack.Active := False;
      b_run.Active := False;
      ActionList[i].Attack(BPlayer);
      BattleHandler.HpPanel.Text := BPlayer.GetHP +'/'+BPlayer.GetMaxHP;
      if BPlayer.GetHP=0 then EndBattle('Lose'); i+=1;
     end);
     ProcessTimer.Start;
    end;

    public
    static procedure EndBattle(Res:string);
    begin
      b_attack.isActive := false; b_run.isActive := false;
      CombatTimer.Stop(); ProcessTimer.Stop(); Stoptimer := False; isPlayerTurn := False;
      if (Res <> 'Run') then begin
        Grid[y, x].GridObject.Destroy();
        Grid[y, x].GridObject := nil;
      end;
      DelayAction(1250, procedure() -> begin
        
        if (Res = 'Win') then begin//Игрок победил
          if (OnExitBattle<>nil) then OnExitBattle();
          Transition.Show('ПОБЕДА', 1000);
        end
        else if (Res = 'Lose') then begin //Иначе проиграл
          Transition.Show('ПОРАЖЕНИЕ', 1000, procedure() -> begin
            CloseLevel();
            BPlayer := nil;
            BgPic.Visible := True;
            DrawMainMenu();
          end);end
        else if (Res = 'Run') then begin
          if (OnExitBattle<>nil) then OnExitBattle();
          Transition.Show('ВЫ СБЕЖАЛИ', 1000);
        end;
        //Удаляем интерфейс, сбрасываем параметры
        b_attack.Destroy(); b_run.Destroy();
        EnemyPanel.Destroy(); DamagePanel.Destroy(); ArmorPanel.Destroy();
        HpPanel.Destroy(); TurnRect.Destroy();

        foreach var tc in EnemyList do begin tc.Destroy(); end; // Уничтожаем врагов
        EnemyList.Clear();
        Enemy.SelectedEnemy := nil; enemyCount := 0;
        CombatPic.Destroy();
      end);
    end;

    static procedure StartBattle(enemys:array of string; xc,yc:integer);
    begin
      (x, y):=(xc,yc);
      Transition.Show('НАЧАЛО БОЯ', 1000, procedure() -> CombatTimer.Start);
      //Отрисовка интерфейса боя
      Redraw(procedure -> begin
        CombatPic := new PictureWPF(0, 0,'data\levels\LALevels\png\CombatField.png');
        b_attack:= new Button(167, 692, 'АТАКА','rect_button_battle.png', 'rect_button_battle_click.png');
        b_run:= new Button(656, 692, 'ПОБЕГ', 'rect_button_battle.png', 'rect_button_battle_click.png');

        TurnRect := new PictureWPF(327, 572, 'img\ui\rect_battle_turn.png');
        TurnRect := ApplyFontSettings(TurnRect) as PictureWPF;
        TurnRect.FontSize := 28;
        
        EnemyPanel:= new PictureWPF(167, 616, 'img\ui\rect_panel_battle.png');
        EnemyPanel := ApplyFontSettings(EnemyPanel) as PictureWPF;

        HpPanel := new PictureWPF(167, 572, 'img\ui\hp_bar.png');
        ArmorPanel := new PictureWPF(936, 572, 'img\ui\rect_battle_mini.png');
        DamagePanel := new PictureWPF(1041, 572, 'img\ui\rect_battle_mini.png');

        var icon := new PictureWPF(0,0,'img\ui\icon_hp.png');
        HpPanel.AddChild(icon, Alignment.LeftTop);
        HpPanel := ApplyFontSettings(HpPanel) as PictureWPF;
        HpPanel.Text := BPlayer.GetHP +'/'+BPlayer.GetMaxHP;
        
        icon := new PictureWPF(0,0,'img\ui\icon_armor.png');
        ArmorPanel.AddChild(icon, Alignment.LeftTop);
        ArmorPanel := ApplyFontSettings(ArmorPanel) as PictureWPF;
        ArmorPanel.Text := BPlayer.SetGetArmor.ToString();

        icon := new PictureWPF(0,0,'img\ui\icon_damage.png');
        DamagePanel.AddChild(icon, Alignment.LeftTop);
        DamagePanel := ApplyFontSettings(DamagePanel) as PictureWPF;
        DamagePanel.Text := BPlayer.GetDamage.ToString();

        EnemyPanel.Text := '';
      end);
      
      b_attack.OnClick += procedure() -> begin
        if (BattleHandler.isPlayerTurn) and (Enemy.SelectedEnemy<> nil) then
        begin BattleHandler.isPlayerTurn:= False;
          BPlayer.Attack(Enemy.SelectedEnemy);
          if (Enemy.SelectedEnemy.GetHP<=0) then enemyCount-=1;
          Enemy.SelectedEnemy.Deselect();
        end;
      end;
     
      b_run.OnClick += procedure() -> begin
        b_run.isActive := False;
        BattleHandler.EndBattle('Run');
      end;
      b_attack.Active := False;
      b_run.Active := False;
      //Спавним противников
      BattleHandler.EnemyList:= new List<Enemy>();
      for var i:= enemys.Length-1 downto 0 do
        case (i+1) of
            3: CreateEnemy(enemys[i], 10, 3);
            2: CreateEnemy(enemys[i], 16, 3);
            4: CreateEnemy(enemys[i], 7, 5);
            1: CreateEnemy(enemys[i], 13, 5);
            5: CreateEnemy(enemys[i], 19, 5);
        end;
      foreach var t in EnemyList do begin if not t.GetDeath then EnemyPanel.Text += t.GetName + '  |  '; end;
      //Начало боя
      CombatTimer := new Timer(250, procedure() ->
      begin
        if (StopTimer) then exit;
        EnemyPanel.Text := '';
        foreach var t in EnemyList do begin if not t.GetDeath then EnemyPanel.Text += t.GetName + '  |  '; end;
        EnemyPanel.Text :=  Copy(EnemyPanel.Text, 1, EnemyPanel.Text.Length - 5);
        if (enemyCount <= 0) then EndBattle('Win'); 
        var ActionList:= new List<BattleEntity>();
        foreach var t in EnemyList do if t.AddAction() then ActionList.Add(t);                
        if BPlayer.AddAction() then ActionList.Add(BPlayer);
        if (ActionList.Count>0) then
        begin Stoptimer:= True; ProcessAttack(ActionList); end;
        end);
      end;
    end;

  MessageCell = class (UseObject)
    private
    messages : array of string;
    public
    constructor Create(messages:array of string);
    begin self.messages := messages; end;

    procedure Use(); override; begin
      DialogHandler.StartDialog(messages);
    end;
    end;
  
  BattleCell = class (UseObject)
    private
    EnemyOnPoint:array of string; //Какие враги в этой точке
    x,y:integer;
    isCompleted:boolean; //Пройден ли бой в этой точке
    isInBattle:boolean; //В бою ли игрок
    ///Проверяет расстояния до игрока, включает видимость огня,
    ///если игрок рядом.
    procedure CheckPlayerDistance(x,y:integer);
    begin
      if (ePointAnim = nil) or (isCompleted) or (isInBattle) then exit;
      //Сколько клеток до игрока
      var distance := Round(Sqrt((self.x - x)**2 + (self.y - y)**2));
      ePointAnim.Visible := (distance < 2);
      
      if (self.x <> x) or (self.y <> y) then exit;
      isInBattle := True;
      if (OnEnterBattle<>nil) then OnEnterBattle();
      //Начинаем бой, если игрок стоит на точке начала боя.
      BattleHandler.StartBattle(EnemyOnPoint, x, y);
    end;

    public
    ePointAnim:LSprite;
    static battleCellCount:integer;

    constructor Create(x,y: integer; EnemyOnPoint: array of string);
    begin
      battleCellCount+=1;
      self.EnemyOnPoint := EnemyOnPoint;
      self.x := x; self.y := y;
      ePointAnim := new LSprite(x,y,'idle', LoadSprites('blue_fire',8));
      var p:Point; p.X := x*48; p.Y := y*48 + 16;
      ePointAnim.Pos := p; ePointAnim.Visible := False; ePointAnim.PlayAnim('idle');
      P.X := x; p.Y := y;
      OnPlayerMove += procedure(x,y:integer) -> CheckPlayerDistance(x,y);
      OnEnterBattle += procedure -> if (ePointAnim <> nil) then ePointAnim.Visible := False;
      OnExitBattle += procedure -> isInBattle := False;
    end;
    
    procedure Destroy(); override;
    begin 
      battleCellCount -= 1;
      isCompleted := True;
      ePointAnim.Destroy(); ePointAnim := nil;
      OnPlayerMove -= procedure(x,y:integer) -> CheckPlayerDistance(x,y);
      OnEnterBattle -= procedure -> if (ePointAnim <> nil) then ePointAnim.Visible := False;
    end;
    end;

  NextLevelCell = class(UseObject)
    private
    levelName:string;
    public
    constructor Create(levelName:string);
    begin
      self.levelName := levelName;
    end;
    ///Переход на следующий уровень.
    procedure Use(); override;
    begin
      if BattleCell.battleCellCount > 0 then begin
        var messages:array of string := ('За моей спиной остались противники, я не могу быть небрежным!');
        DialogHandler.StartDialog(messages);
      end
      else ChangeLevel(levelName);
    end;
    end;
  
  PickableCell = class (UseObject)
    private
    sprite: PictureWPF;
    isPickup: boolean; //Взаимодействовал ли персонаж игрока с объектом
    ///Происходит "подбор" объекта
    procedure Pickup(); virtual; 
    begin isPickup := True; sprite.Destroy(); sprite := nil; end;

    public
    constructor Create(x,y:integer; path:string);
    begin sprite := new PictureWPF(x*48, y*48, path); end;
    procedure Use(); override; begin if not isPickup then Pickup(); end;
    procedure Destroy(); override;
    begin if sprite <> nil then sprite.Destroy(); sprite := nil;  end;
    end;
  
  PotionPickup = class (PickableCell)
    private
    potionPower:integer := 10;
    procedure Pickup(); override;
    begin
      inherited Pickup();
      BPlayer.AddHP(potionPower);
      var messages:array of string := ($'Вы восстановили {potionPower} ед. маны.');
      DialogHandler.StartDialog(messages);
    end;
    public
    constructor Create(x,y:integer; amount:integer);
    begin
      inherited Create(x,y, 'img/potion.png');
      potionPower := amount;
    end;
    end;

  ArmorPickup = class (PickableCell)
    private
    armorValue:integer := 10;
    procedure Pickup(); override;
    begin
      inherited Pickup();
      if (BPlayer.SetGetArmor > armorValue) then begin
        var messages:array of string := ( $'Эта броня хуже вашей.');
        DialogHandler.StartDialog(messages);
        exit;
      end;
      BPlayer.SetGetArmor := armorValue;
      var messages:array of string := ( $'Вы надели броню поглощающую {armorValue} ед. урона.');
      DialogHandler.StartDialog(messages);
    end;
    public
    constructor Create(x,y:integer; amount:integer);
    begin
      inherited Create(x,y, 'img/armor.png'); armorValue := amount;
    end;
    end;

  PlayerWorld = class
    private
    point:RectangleWPF; //Невидимое тело объекта
    useRect:PictureWPF;
    position:GPoint; sprite:LSprite;
    moveTimer, updateSprite:Timer;
    dir:string; speed:integer := 480;
    Blocked:boolean;

    procedure SetBlocking(blocked:boolean);
    begin
      self.blocked := blocked;
      sprite.Visible := not blocked;
      if not blocked then sprite.PlayAnim('rotatedown');
    end;
    
    //Проверяет можно ли использовать клетку на которую смотрит персонаж,
    //или на которой он стоит.
    procedure CheckGridUse();
    begin
      useRect.Visible := False; //По умолчани делаем его False
      var obj := Grid[GetY, GetX].GridObject;
      if (obj <> nil) then
        if (obj is NextLevelCell) then begin useRect.Visible := True; exit; end
        else if (obj is PickableCell) then begin obj.Use(); exit; end;
      
      var dx := 0; var dy := 0;
      case self.dir of 
        'left': dx := -1;'right': dx := 1;
        'up': dy := -1;'down': dy := 1;
      end;

      if (GetX+dx<0) or (GetX+dx>26) or (GetY+dy<0) or (GetY+dy>15) then exit;
      obj := Grid[GetY+dy, GetX+dx].GridObject;
      if (obj<>nil) and (obj is MessageCell) then useRect.Visible := True;
    end;
    
    public
    constructor Create(x,y:integer);
    begin
      position.x := x; position.y := y;
      point := new RectangleWPF(x*48, y*48, 4, 4, Colors.Black);
      point.Visible := False;
      useRect := new PictureWPF(x*48+12, y*48, 'img\ui\rect_small.png');
      useRect := ApplyFontSettings(useRect) as PictureWPF;
      (useRect.FontSize, useRect.Text, useRect.Visible) := (18, 'E', False);
      
      //Инициализация изображений игрока
      sprite := new LSprite(x, y, 'idledown', LoadSprite('player/down2'), 160, False);
      
      sprite.AddAnim('rotateleft', LoadSprite('player/left4'), 100, False);
      sprite.AddAnim('rotateright', LoadSprite('player/right4'), 100, False);
      sprite.AddAnim('rotateup', LoadSprite('player/up2'), 100, False);
      sprite.AddAnim('rotatedown', LoadSprite('player/down2'), 100, False);
      
      sprite.AddAnim('walkleft', LoadSprites('player/left', 4), 120, False);
      sprite.AddAnim('walkright', LoadSprites('player/right', 4), 120, False);
      sprite.AddAnim('walkup', LoadSprites('player/up', 4), 120, False);
      sprite.AddAnim('walkdown', LoadSprites('player/down', 4), 120, False);
      
      sprite.PlayAnim('idledown');
      //*************************
      OnEnterBattle += procedure -> SetBlocking(True);
      OnExitBattle += procedure -> SetBlocking(False);
      //Таймер нужен чтобы игрок не двигался с бесконечным ускорением
      moveTimer := new Timer(speed, procedure -> begin
        moveTimer.Stop();
        if OnPlayerMove <> nil then OnPlayerMove(GetX, GetY);
      end);
      //Обновляем позицию визуального представления игрока
      updateSprite := new Timer(10, procedure() -> begin
        var p := point.LeftTop; p.Y += 12; sprite.Pos := p;
        useRect.MoveTo(point.LeftTop.x+12, point.LeftTop.y-48);
      end);
      updateSprite.Start();
    end;
    
    ///Перемещает игрока в координаты x, y
    procedure SetPos(x,y:integer);
    begin
      (position.x, position.y) := (x, y);
      point.AnimMoveTo(x*48,y*48, 0);
      sprite.PlayAnim('idledown');
      if OnPlayerMove<>nil then OnPlayerMove(GetX, GetY); 
      CheckGridUse();
    end;
    
    procedure MoveOn(x,y:integer; dir:string);
    begin
      self.dir := dir;
      //Не обрабатываем движение, если персонаж уже идёт
      if (moveTimer<>nil) and (moveTimer.Enabled) then exit;
      
      //Проверяем возможность "хода", в случае отсутствия просто "поворачиваем"
      //персонажа в нужную сторону.
      if (GetX+x<0) or (GetX+x>26) or (GetY+y<0) or (GetY+y>15) or Grid[GetY+y, GetX+x].CantGet then 
        sprite.PlayAnim('rotate'+dir)
      else begin //Скорость игрока
        //Обрабатываем "поворот" и движение игрока, включая соответствующую анимацию
        sprite.PlayAnim('walk'+dir);
        position.x += x; position.y += y;
        point.AnimMoveTo(GetX*48, GetY*48, speed/1000.0);
        moveTimer.Start();
      end;
      CheckGridUse();   
    end;
      
    procedure UseGrid();
    begin
      if not useRect.Visible then exit;
      var obj := Grid[GetY, GetX].GridObject;
      if (obj <> nil) and (obj is NextLevelCell) then begin
        obj.Use(); exit;
      end;
      
      var dx := 0; var dy := 0;
      case self.dir of
        'left': dx := -1; 'right': dx := 1;
        'up': dy := -1; 'down': dy := 1;
      end;
      //Если взаимодействуем с клеткой за границей экрана, то просто выходим.
      if (GetX+dx<0) or (GetX+dx>26) or (GetY+dy<0) or (GetY+dy>15) then exit;
      obj := Grid[GetY+dy, GetX+dx].GridObject;
      if (obj<>nil) then obj.Use();
    end;
    
    ///Уничтожаем объект игрока.
    procedure Destroy();
    begin
      OnEnterBattle -= procedure -> SetBlocking(True);
      OnExitBattle -= procedure -> SetBlocking(False);
      moveTimer.Stop(); updateSprite.Stop();
      point.Destroy(); useRect.Destroy(); sprite.Destroy();
    end;
    
    ///Событие окончания движения игрока
    property GetX: integer read floor(position.x);
    property GetY: integer read floor(position.y);
    property isBlocked: boolean read blocked write SetBlocking;
    end;

  
  var Player: PlayerWorld;
  ///Загружает уровень с именем lname и настраивает сетку grid.
  procedure LoadLevel(lname:string);
  begin
    var loader := new LALoader('data/levels/LALevels.ldtk');
    Transition.Show(1000, procedure()-> begin Player.isBlocked := False end);
    var i := -1;
    
    //Находим номер уровня в массиве
    for i := 0 to loader.GetValue&<JToken>('levels').Count()-1 do
      if loader.GetValue&<string>('levels['+i+'].identifier') = lname then break;
    
    var val := loader.GetValue&<JToken>('levels['+i+'].layerInstances[0].entityInstances');
    var x,y:integer;
    if (Player = nil) then Player := new PlayerWorld(1,1);
    if (BPlayer = nil) then BPlayer := new BattlePlayer();
    
    for var j:=0 to val.Count()-1 do begin
      var fields := val[j]['fieldInstances'];
      x := Integer(val[j]['__grid'][0]);
      y := Integer(val[j]['__grid'][1]);
      var cell := Grid[y,x];
      ///Определя
      case val[j]['__identifier'].ToString() of
        'Wall': cell.CantGet := True;
        'SpawnPoint': Player.SetPos(x,y);
        'MessageObject': begin
          //Можно ли "наступить" на объект сообщения
          cell.CantGet := not fields[1]['__value'].ToObject&<boolean>();
          cell.GridObject := new MessageCell(fields[0]['__value'].ToObject&<array of string>());
        end;
        'NextLevel': cell.GridObject := new NextLevelCell(fields[0]['__value'].ToString());
        'EnemyPoint': begin
          var tt:= fields[0]['__value'].ToObject&<array of string>();
          cell.GridObject := new BattleCell(x,y,tt);
        end;
        'Armor': cell.GridObject := new ArmorPickup(x,y,fields[0]['__value'].ToObject&<integer>());
        'Potion': cell.GridObject := new PotionPickup(x,y,fields[0]['__value'].ToObject&<integer>());
      end;
      Grid[y,x] := cell;
    end;
    //Устанавливаем изображение уровня
    LevelPic := new PictureWPF(0, 0,'data/levels/LALevels/png/'+lname+'.png');
    LevelPic.ToBack(); //Перемещаем изображение уровня назад.
  end;
  
  ///Закрывает текущий уровень.
  procedure CloseLevel();
  begin
    if (LevelPic = nil) then exit;
    Player.Destroy(); Player := nil;
    LevelPic.Destroy(); //Уничтожаем старое изображение уровня
    LevelPic := nil;
    for var i := 0 to 15 do
      for var j:= 0 to 26 do begin
        if (Grid[i,j].GridObject <> nil) then Grid[i,j].GridObject.Destroy();
      end;
    var t : levelGrid; //
    Grid := t; // Обнуляем таким образом сетку уровня
  end;
  
  ///Меняет текущий уровень на уровень с именем lname и сохраняет прогресс игрока.
  procedure ChangeLevel(lname:string);
  begin
    CloseLevel();
    //Сохраняем прогресс игрока
    var loader := new LALoader('data/userdata.json');
    loader.SetValue('current_level', lname);
    if (BPlayer <> nil) then begin
      loader.SetValue('hp', BPlayer.GetHP);
      loader.SetValue('armor', BPlayer.SetGetArmor);
    end;
    loader.SaveFile();
    LoadLevel(lname);
  end;
  
  //РАЗДЕЛ ОПИСАНИЯ ГЛАВНОГО МЕНЮ.
  procedure DrawConfirmMenu(text:string; confirm, cancel:procedure);
  var b_confirm, b_cancel: Button;
  begin
    var r_body := new PictureWPF(384, 280, 'img\ui\rect_confirm.png');
    r_body := ApplyFontSettings(r_body) as PictureWPF;
    r_body.Text := text;

    b_confirm := new Button(384, 424, 'ОК', 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_cancel := new Button(656, 424, 'ОТМЕНА', 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    
    b_confirm.OnClick += procedure -> begin 
      confirm; r_body.Destroy(); b_confirm.Destroy(); b_cancel.Destroy(); 
    end;
    
    b_cancel.OnClick += procedure -> begin
      cancel; r_body.Destroy(); b_confirm.Destroy(); b_cancel.Destroy(); 
    end;
  end;
  
  procedure DrawMainMenu();
  var b_continue, b_startNew, b_exit:Button;
  begin
    var loader := new LALoader('data/userdata.json');
    //Отрисовка интерфейса меню
    Redraw(procedure -> begin
      b_continue := new Button(510, 561, 'ПРОДОЛЖИТЬ', 'rect_menu_wide.png', 'rect_menu_wide_click.png');
      b_continue.Active := loader.GetValue&<string>('current_level') <> '';
      b_startNew := new Button(510, 625, 'НОВАЯ ИГРА', 'rect_menu_wide.png', 'rect_menu_wide_click.png');
      b_exit := new Button(510, 689, 'ВЫХОД', 'rect_menu_wide.png', 'rect_menu_wide_click.png');
    end);

    //Делегат, при вызове удаляет кнопки
    var delButtons := procedure() -> begin
      b_continue.Destroy(); b_startNew.Destroy();
      b_exit.Destroy();
    end;
    
    b_continue.OnClick += procedure() -> begin
      //Загружаем прогресс игрока
      ChangeLevel(loader.GetValue&<string>('current_level'));
      delButtons();
      BgPic.Visible := False;
    end;
    
    b_startNew.OnClick += procedure() -> begin
      //Сбрасываем прогресс игрока
      DrawConfirmMenu('НАЧАТЬ НОВУЮ ИГРУ?', 
      procedure() -> begin
        loader.SetValue('current_level', 'Level_0');
        loader.SetValue('hp', loader.GetValue&<integer>('max_hp'));
        loader.SaveFile();
        ChangeLevel(loader.GetValue&<string>('current_level'));
        BgPic.Visible := False;
      end, 
      procedure() -> DrawMainMenu());
      delButtons();
    end;
    b_exit.OnClick += procedure() -> begin writeln('Игра закрыта!'); Halt; end;
  end;
  
  procedure StartGame();
  begin
    Window.Caption := 'Little Adventure';
    Window.IsFixedSize := True; Window.SetSize(1296, 768);
    Window.CenterOnScreen();

    BgPic := new PictureWPF(0,0, 'data\levels\LALevels\png\MenuBackground.png');   
    DrawMainMenu();
  end; 
end.
