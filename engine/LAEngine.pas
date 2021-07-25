unit LAEngine;
{$reference Newtonsoft.Json.dll}
uses Newtonsoft.Json.Linq, WPFObjects, Timers, Loader;

//Вспомогательные методы для работы
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
  if (x>obj.LeftTop.X) and (x<obj.RightTop.X) and (y>obj.LeftTop.Y) and (y<obj.RightBottom.Y) then
  Result:=True;
end;

///Меняет изображение from на изображение из файла по пути too.
procedure ChangePicture(var from:PictureWPF; too:string);
begin var p := from; from := new PictureWPF(p.LeftTop, too); p.Destroy(); end;

function ApplyFontSettings(const obj:ObjectWPF):ObjectWPF;
begin
  (obj.FontName, obj.FontColor, obj.FontSize, obj.TextAlignment) := 
  ('GranaPadano', ARGB(255, 255, 214, 0), 32, Alignment.Center); Result := obj;
end;
//---------------------------------------------

//Опережающее описание процедур
procedure CloseLevel(); forward;
procedure ChangeLevel(lname:string); forward;
procedure DrawMainMenu(); forward;
procedure DrawConfirmMenu(text:string; confirm, cancel:procedure); forward;

type
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
    ///'$.' - в начале пути приписывать ОБЯЗАТЕЛЬНО!
    ///Например: GetValue&<integer>('$.enemy.zombie.hp'); //знак & - тоже обязателен.
    function GetValue<TL>(key:String):TL;
    begin
      var token := jObj.SelectToken(key);
      if (token = nil) then writeln('Такого ключа не существует!')
      else Result := token.ToObject&<TL>();
    end;
    
    ///Устанавливает значение val по пути key в файле json,
    ///если такой путь существует!
    ///Например: SetValue('$.enemy.zombie.hp', 100);
    procedure SetValue<TL>(key:string; val:TL);
    begin
      var v := JToken.FromObject(val as Object);
      var token := jObj.SelectToken(key);
      if (token = nil) then writeln('Такого ключа ', key, ' не существует!')
      else token.Replace(v);
    end;
    
    ///Сохраняет изменения в файле
    procedure SaveFile() := WriteAllText(path, jObj.ToString(), Encoding.UTF8);
  end;
  
  //##############-НАЧАЛО_ИНТЕРФЕЙС-################
  ///Пример использования:
  ///var b:= new Button(100, 200, 'img/ui/play.png', 'img/ui/playpress.png');
  ///b.OnClick += procedure() -> begin КОД КОТОРЫЙ ВЫПОЛНИТСЯ ПРИ НАЖАТИИ КНОПКИ end;
  Button = class
    private
    pic:PictureWPF; isClicked, isActive:boolean;
    idlePic, clickPic, buttonText:string;
    
    ///Изменение спрайта на clickPic
    procedure Clicked(x, y: real; mousebutton: integer);
    begin
      if (pic = nil) or not isActive then exit;
      if (mousebutton <> 1) and (isClicked) then exit;
      if PtInside(x,y,pic) then begin 
        isClicked := True;
        ChangePicture(pic, clickPic); ApplyText();
      end;
    end;
    
    ///Обработка нажатия
    procedure Process(x, y: real; mousebutton: integer);
    begin
      if (pic = nil) or not isActive then exit;
      ChangePicture(pic, idlePic); ApplyText();
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
      isActive := t; var ts:= clickPic;
      if t then ts:= idlePic;
      ChangePicture(pic, ts); ApplyText();
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
      isActive := True;
      self.idlePic := 'img\ui\' + idlePic;
      self.clickPic := 'img\ui\' + clickPic;
      
      pic := new PictureWPF(x, y, self.idlePic);
      OnMouseDown += Clicked; OnMouseUp += Process;
    end;
    
    procedure Destroy();
    begin
      OnMouseDown -= Clicked; OnMouseUp -= Process;
      if (pic = nil) then exit;
      pic.Destroy(); pic := nil;
    end;
    
    property Text: string read buttonText write SetText;
    property Active: boolean read isActive write SetActive;
  end;
  //##############-КОНЕЦ_ИНТЕРФЕЙС-#################
  
  //##############-НАЧАЛО_СПРАЙТЫ-################
  spriteInfo=record
    frames:array of string; //Кадры анимации.
    speed:integer; //Скорость анимации.
    isLoop:boolean; //Зациклена ли анимация.
    AnimProcedure:procedure; //Имеет смысл только если анимация не зациклена.
  end;
  
  LSprite = class
    private
    anims:Dictionary<string, spriteInfo>; //Все анимации по их именам
    curAnim:spriteInfo; //Текущая анимация
    sprite:PictureWPF;
    position:Point;
    updater:Timer;
    frameNum:Integer; //Номер текущего кадра анимации
    isVisible:boolean;
    
    procedure ChangeSprite();
    begin
      Redraw(procedure()-> begin
        sprite.Destroy();
        sprite:= new PictureWPF(0,0, curAnim.frames[frameNum]);
        SetPos(position);
        sprite.Visible := isVisible;
      end);
    end;
    
    //Обновление кадра изображения
    procedure UpdateFrame();
    begin
      if (frameNum<curAnim.frames.Length-1) then frameNum+=1
      else if curAnim.isLoop then frameNum:=0
      else begin updater.Stop(); 
        if (curAnim.AnimProcedure<>nil) then curAnim.AnimProcedure;
        exit;
      end; ChangeSprite();
    end;

    function GetPos():Point;
    begin
      if (sprite <> nil) then Result := sprite.Center
      else Result := position;
    end;
    
    ///Устанавливает позицию спрайта
    procedure SetPos(pos:Point);
    begin
      position := pos;
      pos.X += 24;
      sprite.Center := pos;
    end;

    public
    ///Конструктор с инициализацией стандартной анимации с обычными параметрами
    constructor Create(x,y:integer; aname:string; frames:array of string);
    begin
      Create(x,y,aname, frames, 160, True);
    end;
    
    ///Конструктор с инициализацией стандартной анимации
    constructor Create(x,y:integer; aname:string; frames:array of string; speed:integer; looped:boolean);
    begin
      Visible := True;
      position.x := x * 48; position.y := y * 48;     
      anims := new Dictionary<string, spriteInfo>();
      AddAnim(aname, frames, speed, looped);
      sprite := new PictureWPF(position, anims[aname].frames[0]);
      updater := new Timer(100, UpdateFrame);
      SetPos(position);
    end;
   
    ///Принадлежит ли точка спрайту
    function PtInside(x,y:Real):boolean; begin
    result := LAEngine.PtInside(X,Y,sprite); end;
    
    ///Добавляет новую анимацию с именем aname
    procedure AddAnim(aname:string; frames:array of string; speed:integer; looped:boolean; AnimProcedure:procedure:=nil);
    begin
      var frame:spriteInfo;
      frame.frames:= frames; frame.speed:=speed; frame.isLoop:=looped; frame.AnimProcedure:= AnimProcedure;
      anims.Add(aname, frame);
    end;
    
    ///Проигрывает анимацию с именем aname
    procedure PlayAnim(aname:string);
    begin
      curAnim := anims[aname]; frameNum := 0;
      if (updater.Enabled) then updater.Stop();
      if (curAnim.frames.Length>1) then begin
        updater.Interval := curAnim.speed;
        updater.Start();
      end; ChangeSprite();
    end;
    
    ///Уничтожаем спрайт.
    procedure Destroy();
    begin
      updater.Stop(); sprite.Destroy(); sprite := nil;
    end;
    
    ///Видимость спрайта
    property Pos: Point Read GetPos write SetPos;
    property Visible: boolean write isVisible read isVisible;
    property Width: integer read floor(sprite.Width);
    property Height: integer read floor(sprite.Height);
  end;
  
  ///Загружает спрайт с именем sname.
  function LoadSprite(sname:string):array of string;
  begin
    Result := new string[1]; Result[0] := 'img/'+sname+'.png';
  end;
  
  ///Загружает последовательность спрайтов с именем sname и номерами от 1 до count.
  function LoadSprites(sname:string; count:integer):array of string;
  begin
    Result := new string[count];
    for var i:= 0 to count-1 do Result[i] := 'img/'+sname+(i+1)+'.png';
  end;
  //##############-КОНЕЦ_СПРАЙТЫ-################

  type
  //ОПИСАНИЕ ИНТЕРФЕЙСНОЙ ЧАСТИ
  ITransitionPic = interface
    procedure Show( p:delegate:=nil; delay:integer:=-1);
    procedure Show(message:string; delay:integer:=-1; p:delegate:=nil);
    procedure Hide();
    procedure ToFront();
    property CanHide: boolean read;
  end;

  IUseObject = interface
    procedure Use();
    procedure Destroy();
  end;
  
  IPlayerWorld = interface
    procedure SetPos(x,y:integer);
    procedure MoveOn(x,y:integer; dir:string);
    procedure UseGrid();
    procedure Destroy();
    property OnMoveEvent:delegate read write;
    property OnEnterBattleEvent: delegate read write;
    property GetX: integer read;
    property GetY: integer read;
    property isBlocked: boolean read write;
    property SetUsing: boolean write;
  end;

  IDialogHandler = interface
    procedure StartDialog(messages:array of string);
    function NextMessage():boolean;
  end;
  
  levelGridRecord = record
    CantGet:boolean; //Можно ли ступить на клетку
    GridObject:IUseObject; //Объект на клетке
  end;
  
  levelGridArr = array[0..15, 0..26] of levelGridRecord;
  
  ///Общие данные игры по ходу её выполнения
  ///Обращение к данным делается, например, так: GD.Player
  GD = static class
    public
    static Player:IPlayerWorld; //Игрок в мире
    static Grid:levelGridArr; //Сетка уровня
    static LevelPic, CombatPic, BgPic:PictureWPF;
    static TransPic:ITransitionPic; //Экран перехода
    static DialogHandler:IDialogHandler;
  end;
  
  IBattleEntity = interface
    procedure Destroy();
    procedure Damage(Dmg: integer);
    procedure Attack();
    function AddAction():boolean;
    property GetDelay: integer Read;
  end;
  
  IEnemy = interface (IBattleEntity)
    procedure Select();
    procedure Deselect();
    property GetName:string read;
    property GetCirclePic: PictureWPF read;
    property SetLockThis: boolean write;
  end;
  
  IBattlePlayer = interface (IBattleEntity)
    procedure AddHP(val:integer);
    property GetHP: integer Read;
    property GetMaxHP: integer Read;
    property GetDamage: integer Read;
    property SetGetArmor: integer Read Write;
  end;
  
  //КОНЕЦ ОПИСАНИЯ ИНТЕРФЕЙСНОЙ ЧАСТИ

  BattleEntity = class (IBattleEntity)
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
    procedure Attack();virtual; begin end;
    
    property GetDelay: integer Read delay;
  end;

  BattleHandler = class
    private
    static ProcessTimer: Timer;
    static Stoptimer, isPlayerTurn: boolean;
    static EnemyPanel, DamagePanel, ArmorPanel, HpPanel, TurnRect : PictureWPF;
    static b_attack, b_run: Button;

    //Обработка очереди действий сущностей
    static procedure ProcessAttack(ActionList: List<IBattleEntity>);
    begin
    var i:= 0;
    ProcessTimer := new Timer(100, procedure() -> begin 
      if isPlayerTurn then exit;
      if i = ActionList.Count then begin
        ProcessTimer.Stop(); Stoptimer:=False; exit;
      end;
      ProcessTimer.Interval:= ActionList[i].GetDelay;
      //Ходит игрок
      if ActionList[i] is IBattlePlayer then begin 
        isPlayerTurn:= True; 
        TurnRect.Text := 'ВАШ ХОД';
        i+=1; exit; 
      end;
      TurnRect.Text := 'ХОД ПРОТИВНИКА';
      ActionList[i].Attack(); i+=1;
     end);
     ProcessTimer.Start;
    end;

    public
    static CombatTimer: Timer;
    static EnemyList: List<IEnemy>;
    static Player: IBattlePlayer;
    static SelectedEnemy: IEnemy;
    static OnBattleEndEvent: procedure;
    static enemyCount:integer;

    static procedure EndBattle(Res:string);
    begin
      b_attack.isActive := false; b_run.isActive := false;
      CombatTimer.Stop(); ProcessTimer.Stop(); Stoptimer := False; isPlayerTurn := False;
      if (Res <> 'Run') then begin
        GD.Grid[GD.Player.GetY, GD.Player.GetX].GridObject.Destroy();
        GD.Grid[GD.Player.GetY, GD.Player.GetX].GridObject := nil;
      end;
      DelayAction(1250, procedure() -> begin
        if (Res = 'Win') then //Игрок победил
        begin
          GD.TransPic.Show('ПОБЕДА', 1000, procedure() -> GD.Player.isBlocked := False);
        end
        else if (Res = 'Lose') then begin //Иначе проиграл
          GD.TransPic.Show('ПОРАЖЕНИЕ', 1000, procedure() -> begin
            CloseLevel();
            GD.Player.OnEnterBattleEvent := nil;
            GD.Player.Destroy();
            GD.Player := nil; GD.BgPic.Visible := True;
            BattleHandler.Player := nil;
            DrawMainMenu();
          end);
        end
        else if (Res = 'Run') then begin
          GD.TransPic.Show('ВЫ СБЕЖАЛИ', 1000, procedure() -> GD.Player.isBlocked := False);
        end;
        //Удаляем интерфейс, сбрасываем параметры
        b_attack.Destroy(); b_run.Destroy();
        EnemyPanel.Destroy(); DamagePanel.Destroy(); ArmorPanel.Destroy();
        HpPanel.Destroy(); TurnRect.Destroy();

        foreach var tc in EnemyList do begin tc.Destroy(); end; // Уничтожаем врагов
        EnemyList.Clear();
        OnBattleEndEvent := nil; SelectedEnemy := nil; enemyCount := 0;
        GD.CombatPic.Destroy();
      end);
    end;

    static procedure StartBattle();
      begin
      //Инициализируем элементы интерфейса боя
      b_attack:= new Button(167, 692, 'rect_button_battle.png', 'rect_button_battle_click.png');
      b_attack.Text := 'АТАКА';
      b_attack.OnClick += procedure() -> begin
        if (BattleHandler.isPlayerTurn) and (BattleHandler.SelectedEnemy<> nil) then
        begin BattleHandler.isPlayerTurn:= False;
          BattleHandler.Player.Attack();
          BattleHandler.SelectedEnemy.Deselect();
        end;
      end;

      b_run:= new Button(656, 692, 'rect_button_battle.png', 'rect_button_battle_click.png');
      b_run.Text := 'ПОБЕГ';
      b_run.OnClick += procedure() -> begin
        b_run.isActive := False;
        BattleHandler.EndBattle('Run');
      end;
      
      TurnRect := new PictureWPF(327, 572, 'img\ui\rect_battle_turn.png');
      TurnRect := ApplyFontSettings(TurnRect) as PictureWPF;
      TurnRect.FontSize := 28;
      
      EnemyPanel:= new PictureWPF(167, 616, 'img\ui\rect_panel_battle.png');
      EnemyPanel := ApplyFontSettings(EnemyPanel) as PictureWPF;

      foreach var t in EnemyList do EnemyPanel.Text += t.GetName + '  |  ';
      EnemyPanel.Text :=  Copy(EnemyPanel.Text, 1, EnemyPanel.Text.Length - 5);
      
      HpPanel := new PictureWPF(167, 572, 'img\ui\hp_bar.png');
      ArmorPanel := new PictureWPF(936, 572, 'img\ui\rect_battle_mini.png');
      DamagePanel := new PictureWPF(1041, 572, 'img\ui\rect_battle_mini.png');

      var icon := new PictureWPF(0,0,'img\ui\icon_hp.png');
      HpPanel.AddChild(icon, Alignment.LeftTop);
      HpPanel := ApplyFontSettings(HpPanel) as PictureWPF;
      BattleHandler.HpPanel.Text := Player.GetHP +'/'+Player.GetMaxHP;
      
      icon := new PictureWPF(0,0,'img\ui\icon_armor.png');
      ArmorPanel.AddChild(icon, Alignment.LeftTop);
      ArmorPanel := ApplyFontSettings(ArmorPanel) as PictureWPF;
      ArmorPanel.Text := Player.SetGetArmor.ToString();

      icon := new PictureWPF(0,0,'img\ui\icon_damage.png');
      DamagePanel.AddChild(icon, Alignment.LeftTop);
      DamagePanel := ApplyFontSettings(DamagePanel) as PictureWPF;
      DamagePanel.Text := Player.GetDamage.ToString();
      //Закончили инициализацию интерфейса

      CombatTimer := new Timer(250, procedure() ->
      begin
        if (StopTimer) then exit;
        if (enemyCount <= 0) then EndBattle('Win'); 
        var ActionList:= new List<IBattleEntity>();
        foreach var t in EnemyList do if t.AddAction() then ActionList.Add(t);                 
        if Player.AddAction() then ActionList.Add(Player);
        if (ActionList.Count>0) then
        begin Stoptimer:= True; ProcessAttack(ActionList); end;
        end);
      end;
  end;

  Enemy = class(BattleEntity, IEnemy)
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
      BattleHandler.enemyCount -= 1;
      OnMouseDown -= klik;
      Sprite.PlayAnim('Death');
    end;
    
    function GetCircle():PictureWPF;
    begin
      if (CirclePic<>nil) then Result := CirclePic;
    end;

    public
    constructor Create(x,y:integer);
    begin
      BattleHandler.OnBattleEndEvent += procedure -> Destroy();
      BattleHandler.enemyCount += 1;
      OnMouseDown += klik;
    end;

    procedure CreateCircleShadowPics(yOffset:integer);
    begin
      var sp := Sprite.Pos;
      ShadowPic := new PictureWPF(sp.X-65, sp.Y+Sprite.Height/2-yOffset, 'img\enemy\shadow.png');
      CirclePic:= new PictureWPF(sp.X-65, sp.Y+Sprite.Height/2-45,'img\enemy\circle.png');
      CirclePic.Visible := False;
    end;

    procedure Select();
    begin
      if (BattleHandler.SelectedEnemy<>nil) then 
        BattleHandler.SelectedEnemy.Deselect();
      CirclePic.Visible := True;
      LockThis:= True;
      BattleHandler.SelectedEnemy:= self;
    end;

    procedure Deselect();
    begin
      BattleHandler.SelectedEnemy.GetCirclePic.Visible := False;    
      BattleHandler.SelectedEnemy.SetLockThis:= False;
      BattleHandler.SelectedEnemy := nil;
    end;

    procedure Attack(); override;      
    begin
      if (isDeath) or (BattleHandler.Player.GetHP <= 0) then exit;
      BattleHandler.Player.Damage(attackDmg);
      Sprite.PlayAnim('Attack');
    end;
    
    procedure Damage(Dmg: integer); override;
    begin
      hp -= Dmg;
      if (hp<=0) then Death() else Sprite.PlayAnim('Hit');
    end;

    procedure Destroy(); override;
    begin
      if (Sprite<>nil) then Sprite.Destroy(); Sprite := nil;
      if (ShadowPic<>nil) then ShadowPic.Destroy(); ShadowPic := nil;
      if (CirclePic<>nil) then CirclePic.Destroy(); CirclePic := nil;
    end;
    
    property GetName: string read name;
    property GetCirclePic: PictureWPF read GetCircle;
    property SetLockThis: boolean write LockThis;
    end;
  
  SkeletonEnemy = class(Enemy)
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      (name, hp, attackDmg, agility, Delay) := ('СКЕЛЕТОН', 9, 5, 3, 2000);
      Sprite:= new LSprite(x,y,'Idle',LoadSprites('enemy\Skeleton\idle', 6));
      Sprite.AddAnim('Hit', LoadSprites('enemy\Skeleton\hit', 4), 160, False, procedure()->
        Sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Attack', LoadSprites('enemy\Skeleton\attack', 10), 160, False, procedure()->
      sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Death', LoadSprites('enemy\Skeleton\death', 5), 160, False);
      Sprite.PlayAnim('Idle');
      CreateCircleShadowPics(40);
    end;
    end;
  
  TreeEnemy = class(Enemy)
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      (name, hp, attackDmg, agility, Delay) := ('ДРЕВО', 15, 4, 2, 2000);
      Sprite:= new LSprite(x,y,'Idle',LoadSprites('enemy\Sprout\idle', 4));
      Sprite.AddAnim('Hit', LoadSprites('enemy\Sprout\hit', 5), 160, False, procedure()->
        Sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Attack', LoadSprites('enemy\Sprout\attack', 6), 160, False, procedure()->
        Sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Death', LoadSprites('enemy\Sprout\death', 8), 160, False);
      Sprite.PlayAnim('Idle');
      CreateCircleShadowPics(45);
    end;
    end;
  
  GolemEnemy = class(Enemy)
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      (name, hp, attackDmg, agility, Delay) := ('ГОЛЕМ <БОСС>', 30, 10, 8, 2000);
      Sprite:= new LSprite(x, y, 'Idle', LoadSprites('enemy\Golem\idle', 6));
      Sprite.AddAnim('Hit', LoadSprites('enemy\Golem\hit', 4), 160, False, procedure()->
        sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Attack', LoadSprites('enemy\Golem\attack', 8), 160, False, procedure()->
        Sprite.PlayAnim('Idle'));
      Sprite.AddAnim('Death', LoadSprites('enemy\Golem\death', 10), 160, False);
      Sprite.PlayAnim('Idle'); //Включаем как анимацию по умолчанию
      CreateCircleShadowPics(45);
    end;
    end;
  
  BattlePlayer = class(BattleEntity, IBattlePlayer)
    private
    max_hp, armor:integer; //Максимальное здоровье игрока
    procedure Death();
    begin
      Writeln('Игрок проиграл'); BattleHandler.EndBattle('Lose');
    end;
    public
    constructor Create();
    begin
      var loader := new LALoader('data/userdata.json');
      max_hp:= 20;
      hp:= loader.GetValue&<integer>('$.hp');
      armor:= loader.GetValue&<integer>('$.armor');
      attackDmg:= 8;
      agility:= 5;
      Delay:= 250;
    end;
    
    procedure Attack();override;      
    begin
      if (BattleHandler.SelectedEnemy = nil) then exit; 
      BattleHandler.SelectedEnemy.Damage(AttackDmg);
    end;

    procedure AddHP(val:integer);
    begin
      hp += val;
      if hp>max_hp then hp := max_hp;
    end;
        
    procedure Damage(Dmg: integer);override;
    begin
      Dmg -= armor; if Dmg<=0 then Dmg := 1;
      hp -= Dmg;
      if (hp<=0) then begin
        hp := 0;
        BattleHandler.HpPanel.Text := hp +'/'+max_hp;
        Death(); exit;
      end;
      BattleHandler.HpPanel.Text := hp +'/'+max_hp;
    end;
    
    property GetHP: integer Read hp;
    property GetMaxHP: integer Read max_hp;
    property GetDamage: integer Read attackDmg;
    property SetGetArmor: integer Read armor Write armor;
    end;
  
  
  DialogHandler = class(IDialogHandler)
    private
    messages : array of string;
    messageNum, messageCount:integer; //Текущий номер сообщения и текущий символ сообщения
    messageTimer:Timer;
    dialogRect:PictureWPF;
    isDialogue: boolean; //Идёт ли диалог
    procedure EndDialogue();
    begin
      GD.Player.SetUsing := False;
      dialogRect.Visible := False;
      messageTimer.Stop();
      isDialogue := False;
    end;
    public
    constructor Create();
    begin
      if (dialogRect = nil) then Redraw(procedure() -> begin
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

    procedure StartDialog(messages:array of string);
    begin
      dialogRect.ToFront();
      (messageNum, messageCount, self.messages, isDialogue) := (-1,1,messages, True);
      dialogRect.Visible := True;
      GD.Player.SetUsing := True;
      NextMessage();
    end;

    function NextMessage():boolean;
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
  end;
  
  UseObject = class(IUseObject)
    public
    procedure Use(); virtual; begin end;
    procedure Destroy(); virtual; begin end;
  end;
  
  MessageCell = class (UseObject)
    private
    messages : array of string;
    public
    constructor Create(messages:array of string);
    begin self.messages := messages; end;

    procedure Use(); override; begin
      if (GD.DialogHandler <> nil) then GD.DialogHandler.StartDialog(messages);
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
    procedure CheckPlayerDistance();
    begin
      if (ePointAnim = nil) or (isCompleted) then exit;
      //Сколько клеток до игрока
      var distance := Round(Sqrt((x - GD.Player.GetX)**2 + (y - GD.Player.GetY)**2));
      if (distance < 2) then ePointAnim.Visible := True else ePointAnim.Visible := False;
      
      if (GD.Player.GetX <> x) or (GD.Player.GetY <> y) then exit;
      DelayAction(500, procedure -> GD.Player.OnEnterBattleEvent);
      //Начинаем бой, если игрок стоит на точке начала боя.
      GD.TransPic.Show('Начало боя', 1000, procedure -> BattleHandler.CombatTimer.Start);
      GD.Player.isBlocked := True; //Блокируем управление игроком
      GD.CombatPic := new PictureWPF(0, 0,'data\levels\LALevels\png\CombatField.png');

      BattleHandler.EnemyList:= new List<IEnemy>();
      for var i:= 0 to EnemyOnPoint.Length-1 do
        case (i+1) of
            1: CreateEnemy(i, 13, 5);
            2: CreateEnemy(i, 16, 3);
            3: CreateEnemy(i, 10, 3);
            4: CreateEnemy(i, 7, 5);
            5: CreateEnemy(i, 19, 5);
        end;
      BattleHandler.StartBattle();
    end;

    procedure CreateEnemy(Index:integer; X,Y:integer);
    begin
      var E: IEnemy;
      case EnemyOnPoint[Index] of
        'Skeleton': E:= new SkeletonEnemy(X,Y);
        'TreeEnemy': E:= new TreeEnemy(X,Y);
        'Golem': E:= new GolemEnemy(X,Y);
      end; BattleHandler.EnemyList.Add(E);
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
      GD.Player.OnMoveEvent += procedure -> CheckPlayerDistance();
      GD.Player.OnEnterBattleEvent += procedure -> if (ePointAnim <> nil) then ePointAnim.Visible := False;
    end;
    
    procedure Destroy(); override;
    begin 
      battleCellCount -= 1;
      isCompleted := True;
      ePointAnim.Destroy(); ePointAnim := nil;
      GD.Player.OnMoveEvent -= procedure -> CheckPlayerDistance();
      GD.Player.OnEnterBattleEvent -= procedure -> if (ePointAnim <> nil) then ePointAnim.Visible := False;
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
        GD.DialogHandler.StartDialog(messages);
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
    begin if sprite <> nil then sprite.Destroy(); end;
    end;
  
  PotionPickup = class (PickableCell)
    private
    potionPower:integer := 10;
    procedure Pickup(); override;
    begin
      inherited Pickup();
      BattleHandler.Player.AddHP(potionPower);
      var messages:array of string := ($'Вы восстановили {potionPower} ед. маны.');
      GD.DialogHandler.StartDialog(messages);
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
      BattleHandler.Player.SetGetArmor := armorValue;
      var messages:array of string := ( $'Вы надели броню поглощающую {armorValue} ед. урона.');
      GD.DialogHandler.StartDialog(messages);
    end;
    public
    constructor Create(x,y:integer; amount:integer);
    begin
      inherited Create(x,y, 'img/armor.png');
      armorValue := amount;
    end;
    end;

  ///Класс игрока в "мире".
  PlayerWorld = class (IPlayerWorld)
    private
    point:RectangleWPF; //Невидимое тело объекта
    useRect:PictureWPF;
    position:GPoint; sprite:LSprite;
    moveTimer, updateSprite:Timer;
    dir:string; speed:integer := 200;
    isUsing, blocked:boolean;
    MoveEvent, InBattleEvent:delegate;

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
      var obj := GD.Grid[GetY, GetX].GridObject;
      if (obj <> nil) then
        if (obj is NextLevelCell) then begin useRect.Visible := True; exit; end
        else if (obj is PickableCell) then begin obj.Use(); exit; end;
      
      var dx := 0; var dy := 0;
      case self.dir of 
        'left': dx := -1;'right': dx := 1;
        'up': dy := -1;'down': dy := 1;
      end;

      if (GetX+dx<0) or (GetX+dx>26) or (GetY+dy<0) or (GetY+dy>15) then exit;
      
      obj := GD.Grid[GetY+dy, GetX+dx].GridObject;
      if (obj<>nil) and (obj is MessageCell) then useRect.Visible := True;
    end;
    
    public
     //Заблокировано ли управление игроком
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
      
      sprite.AddAnim('walkleft', LoadSprites('player/left', 4), 160, False);
      sprite.AddAnim('walkright', LoadSprites('player/right', 4), 160, False);
      sprite.AddAnim('walkup', LoadSprites('player/up', 4), 160, False);
      sprite.AddAnim('walkdown', LoadSprites('player/down', 4), 160, False);
      
      sprite.PlayAnim('idledown');
      //*************************
      //Таймер нужен чтобы игрок не двигался с бесконечным ускорением
      moveTimer := new Timer(speed, procedure -> begin moveTimer.Stop(); MoveEvent; end);
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
      MoveEvent(); CheckGridUse();
    end;
    
    procedure MoveOn(x,y:integer; dir:string);
    begin
      if isUsing then exit; self.dir := dir;
      //Не обрабатываем движение, если персонаж уже идёт
      if (moveTimer<>nil) and (moveTimer.Enabled) then exit;
      
      //Проверяем возможность "хода", в случае отсутствия просто "поворачиваем"
      //персонажа в нужную сторону.
      if (GetX+x<0) or (GetX+x>26) or (GetY+y<0) or (GetY+y>15) or GD.Grid[GetY+y, GetX+x].CantGet then 
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
      var obj := GD.Grid[GetY, GetX].GridObject;
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
      obj := GD.Grid[GetY+dy, GetX+dx].GridObject;
      if (obj<>nil) then obj.Use();
    end;
    
    ///Уничтожаем объект игрока.
    procedure Destroy();
    begin
      moveTimer.Stop(); updateSprite.Stop();
      point.Destroy(); useRect.Destroy(); sprite.Destroy();
    end;
    
    ///Событие окончания движения игрока
    property OnMoveEvent: delegate read MoveEvent write MoveEvent;
    property OnEnterBattleEvent: delegate read InBattleEvent write InBattleEvent;
    property GetX: integer read floor(position.x);
    property GetY: integer read floor(position.y);
    property isBlocked: boolean read blocked write SetBlocking;
    property SetUsing: boolean write isUsing;
  end;
  
  TransitionPic = class (ITransitionPic)
    private
    pic:RectangleWPF;
    isCanHide:boolean;
    proc:delegate;
    public
    constructor Create;
    begin
      Redraw(procedure()-> begin
        pic := new RectangleWPF(0, 0, 1296, 768, Colors.Black);
        pic := ApplyFontSettings(pic) as RectangleWPF; pic.Visible := False;
      end);
      OnDrawFrame += procedure(dt:real) -> GD.TransPic.ToFront();
    end;
    
    ///Показать изображение перехода
    procedure Show(p:delegate:=nil; delay:integer:=-1) := Show('Для продолжения нажмите ПРОБЕЛ', delay, p);
    
    ///Показать изображение перехода с нужным текстом после загрузки
    procedure Show(message:string; delay:integer:=-1; p:delegate:=nil);
    begin
      proc:=p;
      if (GD.player <> nil) then GD.player.isBlocked := True; //Блокируем движение игрока
      
      if (delay <> -1) then begin
        Redraw(procedure -> (pic.Visible, pic.Text) := (True, message));
        DelayAction(delay, procedure -> Hide()); exit;
      end;
      
      Redraw(procedure -> (pic.Visible, pic.Text) := (True, 'Загрузка уровня...'));

      DelayAction(1000, procedure -> begin
        isCanHide := True; pic.Text := message; end);
    end;
    
    ///Скрыть изображение перехода
    procedure Hide();
    begin
      if (proc<>nil) then proc;
      isCanHide := False; pic.Visible := False;
    end;
    
    procedure ToFront();
    begin if (pic <> nil) then pic.ToFront(); end;
    
    property CanHide:boolean read isCanHide;
  end;
  
  ///Загружает уровень с именем lname и настраивает сетку grid.
  procedure LoadLevel(lname:string);
  begin
    var loader := new LALoader('data/levels/LALevels.ldtk');
    GD.TransPic.Show(procedure()-> begin GD.Player.isBlocked := False end);
    var i := -1;
    
    //Находим номер уровня в массиве
    for i := 0 to loader.GetValue&<JToken>('$.levels').Count()-1 do
      if loader.GetValue&<string>('$.levels['+i+'].identifier') = lname then break;
    
    var val := loader.GetValue&<JToken>('$.levels['+i+'].layerInstances[0].entityInstances');
    var x,y:integer;
    if (GD.Player = nil) then GD.Player := new PlayerWorld(1,1);
    for var j:=0 to val.Count()-1 do begin
      var fields := val[j]['fieldInstances'];
      x := Integer(val[j]['__grid'][0]);
      y := Integer(val[j]['__grid'][1]);
      var cell := GD.Grid[y,x];
      ///Определя
      case val[j]['__identifier'].ToString() of
        'Wall': cell.CantGet := True;
        'SpawnPoint': GD.Player.SetPos(x,y);
        'MessageObject': begin
          //Можно ли "наступить" на объект сообщения
          if (fields[1]['__value'].ToString() = 'False') then cell.CantGet := True;
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
      GD.Grid[y,x] := cell;
    end;
    //Устанавливаем изображение уровня
    GD.LevelPic := new PictureWPF(0, 0,'data/levels/LALevels/png/'+lname+'.png');
    GD.LevelPic.ToBack(); //Перемещаем изображение уровня назад.
    
    if (BattleHandler.Player = nil) then 
        BattleHandler.Player:= new BattlePlayer;
  end;
  
  ///Закрывает текущий уровень
  procedure CloseLevel();
  begin
    if (GD.LevelPic = nil) then exit;
    GD.LevelPic.Destroy(); //Уничтожаем старое изображение уровня
    GD.LevelPic := nil;
    for var i := 0 to 15 do
      for var j:= 0 to 26 do begin
        if (GD.Grid[i,j].GridObject <> nil) then GD.Grid[i,j].GridObject.Destroy();
      end;
    var t : levelGridArr; //
    GD.Grid := t; // Обнуляем таким образом сетку уровня
  end;
  
  ///Меняет текущий уровень на уровень с именем lname
  procedure ChangeLevel(lname:string);
  begin
    CloseLevel();
    //Сохраняем прогресс игрока
    var loader := new LALoader('data/userdata.json');
    loader.SetValue('$.current_level', lname);
    if (BattleHandler.Player <> nil) then begin
      loader.SetValue('$.hp', BattleHandler.Player.GetHP);
      loader.SetValue('$.armor', BattleHandler.Player.SetGetArmor);
      end;
    loader.SaveFile();
    LoadLevel(lname);
  end;
  
  //РАЗДЕЛ ОПИСАНИЯ ГЛАВНОГО МЕНЮ
  procedure DrawConfirmMenu(text:string; confirm, cancel:procedure);
  var b_confirm, b_cancel: Button;
  begin
    var r_body := new PictureWPF(384, 280, 'img\ui\rect_confirm.png');
    r_body.Text := text;
    r_body := ApplyFontSettings(r_body) as PictureWPF;

    b_confirm := new Button(384, 424, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_confirm.Text := 'ОК';
    b_cancel := new Button(656, 424, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_cancel.Text := 'ОТМЕНА';
    
    b_confirm.OnClick += procedure() -> begin 
      confirm; 
      r_body.Destroy(); b_confirm.Destroy(); b_cancel.Destroy(); 
    end;
    
    b_cancel.OnClick += procedure() -> begin
      cancel; 
      r_body.Destroy(); b_confirm.Destroy(); b_cancel.Destroy(); 
    end;
  end;
  
  procedure DrawRulesMenu();
  var b_prev, b_next, b_back:Button;
  begin
    b_prev := new Button(309, 598, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_prev.Text := 'ПРЕДЫДУЩИЙ';
    
    b_back := new Button(581, 598, 'rect_menu_rules_short.png', 'rect_menu_rules_short_click.png');
    b_back.Text := 'В МЕНЮ';
    
    b_next := new Button(731, 598, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_next.Text := 'СЛЕДУЮЩИЙ';
    
    b_back.OnClick += procedure() -> begin
      DrawMainMenu();
      b_prev.Destroy(); b_back.Destroy(); b_next.Destroy();
    end;
  end;
  
  procedure DrawMainMenu();
  var b_continue, b_startNew, b_rules, b_about, b_exit:Button;
  begin
    var loader := new LALoader('data/userdata.json');
    
    b_continue := new Button(32, 694, 'rect_menu_wide.png', 'rect_menu_wide_click.png');
    b_continue.Text := 'ПРОДОЛЖИТЬ'; 
    if loader.GetValue&<string>('$.current_level') = '' then b_continue.Active := False;
    
    b_startNew := new Button(345, 694, 'rect_menu_wide.png', 'rect_menu_wide_click.png');
    b_startNew.Text := 'НОВАЯ ИГРА';
    
    b_rules := new Button(656, 694, 'rect_menu_short.png', 'rect_menu_short_click.png');
    b_rules.Text := 'ПРАВИЛА';
   
    b_about := new Button(864, 694, 'rect_menu_short.png', 'rect_menu_short_click.png');
    b_about.Text := 'О ПРОЕКТЕ';

    ///Завершает работу игры.
    b_exit := new Button(1072, 694, 'rect_menu_short.png', 'rect_menu_short_click.png');
    b_exit.Text := 'ВЫХОД';
    
    //Делегат, при вызове удаляет кнопки
    var delButtons := procedure() -> begin
      b_continue.Destroy(); b_startNew.Destroy();
      b_rules.Destroy(); b_about.Destroy(); b_exit.Destroy();
    end;
    
    b_continue.OnClick += procedure() -> begin
      //Загружаем прогресс игрока
      ChangeLevel(loader.GetValue&<string>('$.current_level'));
      delButtons();
      GD.BgPic.Visible := False;
    end;
    
    b_startNew.OnClick += procedure() -> begin
      //Сбрасываем прогресс игрока
      DrawConfirmMenu('НАЧАТЬ НОВУЮ ИГРУ?', 
      procedure() -> begin
        loader.SetValue('$.current_level', 'Level_0');
        loader.SaveFile();
        ChangeLevel(loader.GetValue&<string>('$.current_level'));
        GD.BgPic.Visible := False;
      end, 
      procedure() ->DrawMainMenu());
      delButtons();
    end;
    
    b_rules.OnClick += procedure() -> begin DrawRulesMenu(); delButtons; end;
    b_about.OnClick += procedure() -> begin end;
    b_exit.OnClick += procedure() -> begin writeln('Игра закрыта!'); Halt; end;
  end;
  
  procedure StartGame();
  begin
    Window.Caption := 'Little Adventure';
    Window.IsFixedSize := True; Window.SetSize(1296, 768);
    Window.CenterOnScreen();

    GD.BgPic := new PictureWPF(0,0, 'img\MainMenuField1.png');   
    if (GD.TransPic = nil) then GD.TransPic := new TransitionPic();
    if (GD.DialogHandler = nil) then GD.DialogHandler := new DialogHandler();
    DrawMainMenu();
  end;
end.