uses SysUtils, RegExpr, Classes;

const
	ATACK_RANGE = 1200;
	HEAL_HP = 80;
	DEATH_DELAY = 2000;
	SOE_ITEM = 736;
	SOE_DELAY = 20000;
	BUFFS_COUNT = 1;
	STATUS_KEY = ' ';

type
	TSkill = (DEATH_SPIKE_SKILL = 1148,
			  VAMPIRIC_CLAW_SKILL = 1234);

	TBuff = (ARCANE_BUFF = 337,
			 SHIELD_BUFF = 1040);

	TMob = (REGULAR_MOB,
			CHAMPION_MOB);

var
	Point : array[0..2] of integer = (44280, 149304, -3600);
	Buffs : array[0..BUFFS_COUNT - 1] of integer = (Integer(ARCANE_BUFF));
	Status : boolean = false;

///////////////////////////////////////////////////////////
//
//                  WINAPI FUNCTIONS
//
///////////////////////////////////////////////////////////

function GetAsyncKeyState(vKey: integer): integer; stdcall; external 'user32.dll';

///////////////////////////////////////////////////////////
//
//                       HELPERS
//
///////////////////////////////////////////////////////////

function SendBypass(dlg: string): boolean;
var
    RegExp : TRegExpr;
    List : TStringList;
    i : integer;
    bps : string;
begin
    result:= true;
    RegExp:= TRegExpr.Create;
    List:= TStringList.Create;
  
    RegExp.Expression:= '(<a *(.+?)</a>)|(<button *(.+?)>)';
    if RegExp.Exec(Engine.DlgText)
    then begin
        repeat List.Add(RegExp.Match[0]);
        until (not RegExp.ExecNext);
    end;

    for i := 0 to List.Count - 1 do
    begin
        if (Pos(dlg, List[i]) > 0)
        then begin
            RegExp.Expression:= '"bypass -h *(.+?)"';
            if RegExp.Exec(List[i])
            then bps:= TrimLeft(Copy(RegExp.Match[0], 12, Length(RegExp.Match[0]) - 12));
        end;
    end;

    if (Length(bps) > 0)
    then Engine.BypassToServer(bps);
  
    RegExp.Free;
    List.Free;
end;

function FindTarget(mob : TMob) : boolean;
var
	i : integer;
	target : TL2Npc;
begin
	for i := 0 to NpcList.Count - 1 do
	begin
		target := NpcList.Items(i);
		if (User.DistTo(target) <= ATACK_RANGE)
			and (not target.Dead) and (target.Attackable)
		then begin
			if (mob = CHAMPION_MOB) and (target.Team > 0)
			then begin
				Engine.SetTarget(target);
				result := true;
				exit;
			end;

			if (mob = REGULAR_MOB)
			then begin
				Engine.SetTarget(target);
				result := true;
				exit;
			end;
		end;
	end;
	result := false;
end;

procedure Attack();
begin
	if (not User.Target.Dead)
	then begin
		Engine.UseSkill(Integer(DEATH_SPIKE_SKILL), false, false);
		delay(1);
		if (User.HP < HEAL_HP)
		then begin
			Engine.UseSkill(Integer(VAMPIRIC_CLAW_SKILL), false, false);
			delay(1);
		end;
	end;
end;

procedure MoveToPoint();
begin
	Engine.DMoveTo(Point[0], Point[1], Point[2]);
	delay(5000);
end;

procedure SelfBuff();
var
    buff : TL2Skill;
    i : integer;
begin
    for i := 0 to BUFFS_COUNT - 1 do
    begin
        if (not User.Buffs.ByID(Integer(Buffs[i]), buff))
        then begin
            Engine.UseSkill(Integer(Buffs[i]));
            Delay(800);
        end;
    end;

    delay(100);
end;

procedure ReturnHome();
begin
	Status := false;
	delay(4000);
	Engine.MoveTo(17928, 145448, -3072);
	Engine.SetTarget(77781);
	Engine.DlgOpen();
	SendBypass('Бафф персонажа');
	delay(1000);
	SendBypass('Набор Мага');
	delay(1000);
	Engine.MoveTo(18168, 145288, -3072);
	Engine.SetTarget(77778);
	Engine.DlgOpen();
	SendBypass('Лёгкий Farm');
	delay(4000);
	Engine.MoveTo(Point[0], Point[1], Point[2]);
	Status := true;
end;

procedure FindTargetThread();
begin
	while True do
	begin
		if (Status)
		then begin
			if (not FindTarget(CHAMPION_MOB))
			then FindTarget(REGULAR_MOB);
		end;
		delay(10);
	end;
end;

procedure AttackThread();
begin
	while True do
	begin
		if (Status)
		then Attack();
		delay(10);
	end;
end;

procedure MoveThread();
begin
	while True do
	begin
		if (Status)
		then MoveToPoint();
	end;
end;

procedure ReturnHomeThread();
var
    buff : TL2Skill;
begin
    while True do
    begin
        if (User.Dead)
        then begin
        	Engine.GoHome();
        	ReturnHome();
            Delay(DEATH_DELAY);
        end;

        if (not User.Buffs.ByID(Integer(SHIELD_BUFF), buff))
        then begin
        	Status := false;
        	Engine.UseItem(SOE_ITEM);
        	Delay(SOE_DELAY);
        	ReturnHome();
        end;
        delay(10);
    end;
end;

procedure BuffsThread();
begin
	while True do
	begin
		if (Status)
		then SelfBuff();
		delay(10);
	end;
end;

procedure ReadStatusKeyThread();
begin
    Status := false;

    while True do
    begin
        while GetAsyncKeyState(ord(STATUS_KEY)) = 0 do Delay(100);
        if (Status)
        then begin
            Engine.GamePrint('Script: STOP', 'FARM', 3);
            Status := false;
        end else
        begin
            Engine.GamePrint('Script: RUN', 'FARM', 3);
            Status := true;
        end;
        Delay(600);
    end;
end;

begin
	script.NewThread(@FindTargetThread);
	script.NewThread(@AttackThread);
	script.NewThread(@MoveThread);
	script.NewThread(@ReturnHomeThread);
	script.NewThread(@BuffsThread);
	script.NewThread(@ReadStatusKeyThread);
end.