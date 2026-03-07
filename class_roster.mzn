include "globals.mzn";

% Constants
enum WEEKDAYS = {Mon, Tue, Wed, Thu, Fri, Sat, Sun};
enum DUTIES = {N, A, P, O, D};
enum TYPES0 = {LADYBUG, BUTTERFLY, DRAGONFLY, BEE, NIGHT, OFFICE, HOME};
enum RULES = {WardReqDuty,            % ward request duty constraint
              ContractDayOff,         % contract O + public holiday O entitlement constraint
              WeekendOff,             % # of weekend O constraint
              NoWeekendPP,            % no weekend PP constraint (mandatory)
              MinWardStaffReq,        % daily ward requirement constraint (mandatory)
              NormalDutyStateDiagram, % normal AN constraint
              NormalNightFrequency,   % at most 1 N for CN days constraint (mandatory)
              CallNightDuty,          % call night then O constraint (mandatory)
              NormalOffFrequency,     % at least 1 O for NW days constraint (mandatory)
              ReqAnnualLeaves,        % requested annual leaves (mandatory)
              LongNightDuties,        % requested long night duties (mandatory)
              PublicHolidayOff,       % # of public holiday O constraint
              WardDayDuty             % ward requested D duty constraint
              };
enum MINS = { shift, ladybug, butterfly, dragonfly, bee, night };
array[DUTIES] of string: lowercase = ["n", "a", "p", "o", "d"];
array[CLASSES] of string: shortform = ["L", "F", "D", "B", "N"];

% Parameters
int: nRosterDays; % number of days in the roster
int: MW;          % maximum number of consecutive shifts
int: nLADYBUG;    % number of staffs in LADYBUG class
int: nBUTTERFLY;  % number of staffs in BUTTERFLY class
int: nDRAGONFLY;  % number of staffs in DRAGONFLY class
int: nBEE;        % number of staffs in BEE class
int: nNIGHT;      % number of NIGHT staffs
int: nCO;         % minimum number of Os in roster
WEEKDAYS: MONTH_START;
array[int, int] of int: min_ward;
array[int, int] of int: max_ward;
array[int, int] of int: staff_req_duties;
array[int, int] of int: ward_req_duties;
set of DAYS: call_req_duties;
array[RULES] of bool: active_constraints;
set of DAYS: public_holidays;

% Tuples/Records
type ClassMins = tuple(CLASSES, MINS);
type ReqDuties = tuple(STAFFS, DAYS, DUTIES);
type Assignment = record(DUTIES: duty, TYPES0: place);

% Derived Parameters
enum STAFFS = LYG(1..nLADYBUG) ++ BFY(1..nBUTTERFLY) ++ DNY(1..nDRAGONFLY) ++ BEE(1..nBEE) ++ NGT(1..nNIGHT);
int: nStaffs = card(STAFFS);
int: nWeekends = card(weekends);
int: nDuties = card(DUTIES);
int: nClasses = card(CLASSES);
int: nPHs = card(public_holidays);
set of TYPES0: CLASSES = {LADYBUG, BUTTERFLY, DRAGONFLY, BEE, NIGHT};
array[CLASSES] of int: nClassStaffs = [nLADYBUG, nBUTTERFLY, nDRAGONFLY, nBEE, nNIGHT];
array[CLASSES] of ClassMins: CLASS_MINS = [(LADYBUG, ladybug), (BUTTERFLY, butterfly), (DRAGONFLY, dragonfly), (BEE, bee), (NIGHT, night)];
set of WEEKDAYS: WEEKEND = {Sat, Sun};
set of DUTIES: SHIFTS = {N, A, P};
set of DUTIES: OFF = {O};
array[int] of Assignment: allAssignments = [(duty: i, place: j) | i in SHIFTS where i != N, j in CLASSES where j != NIGHT] ++ 
                                           [(duty: N, place: NIGHT), (duty: O, place: HOME), (duty: D, place: OFFICE)];
set of int: ASSIGNMENTS0 = 1..length(allAssignments);
set of ASSIGNMENTS0: ASSIGNMENTS = 1..9;    % 4 classes for A/P + 1 night

% Derived Parameters (for cross-month calendar generation)
int: nPrevMthDays = 7;
int: nNextMthDays = 2;
enum DAYS = V(1..nPrevMthDays) ++ C(1..nRosterDays) ++ X(1..nNextMthDays);
array[DAYS] of WEEKDAYS: DAY_WEEKDAYS = [weekday(i) | i in DAYS];
set of DAYS: weekends = array2set([i | i in DAYS where DAY_WEEKDAYS[i] in WEEKEND]);
int: nDays = card(DAYS);

% Derived Parameters
array[CLASSES] of set of STAFFS: CLASS_STAFFS = [LYG(1..nLADYBUG), BFY(1..nBUTTERFLY), DNY(1..nDRAGONFLY), BEE(1..nBEE), NGT(1..nNIGHT)];
array[int] of int: MIN_WARD = convert(min_ward);
array[int] of int: MAX_WARD = convert(max_ward);

% Derived Parameters (for requested duties)
array[int] of ReqDuties: STAFF_REQ_DUTIES = req_duties(staff_req_duties);
array[int] of ReqDuties: WARD_REQ_DUTIES = req_duties(ward_req_duties);

% Function to get mask value for specific staff/day (P/O/<> pattern)
%function opt DUTIES: get_special_mask(STAFFS: s, DAYS: d) =
%    let {
%        int: row = long_night_row(s,d)
%    } in
%    if row > 0 then
%        if d == long_nights[row,2] then 
%            if occurs(long_night_duties[s, enum_prev(d)]) then O else P endif  % First day
%        else O endif    % Next 13 days after start
%    else <> endif;      % All other days

% Create the mask array
%array[STAFFS, DAYS] of opt DUTIES: special_mask = 
%    array2d(STAFFS, DAYS, [get_special_mask(s,d) | s in STAFFS, d in DAYS]);

% Function to apply mask
%function array[DAYS] of var DUTIES: apply_special_mask(STAFFS: s, array[DAYS] of var DUTIES: staff_roster) =
%    array1d(DAYS, [if occurs(special_mask[s,d]) then deopt(special_mask[s,d]) else staff_roster[d] endif
%                  | d in DAYS ]);

% Decision Variables
array[STAFFS, DAYS] of var ASSIGNMENTS0: roster;
array[DAYS, ASSIGNMENTS0] of var set of STAFFS: ward;
array[DAYS] of var opt STAFFS: call;
array[STAFFS, DUTIES] of var int: staff_duty_counts;
array[DAYS, ASSIGNMENTS] of var int: ward_shift_manpower;

% Channel constraints for roster/ward
constraint forall(i in DAYS) (
    partition_set(row(ward,i), STAFFS)
);
constraint forall(i in DAYS) (
    int_set_channel(col(roster,i), row(ward,i))
);
constraint forall(i in STAFFS) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in global_cardinality([assignment_to_duty(temp[j]) | j in DAYS], DUTIES, row(staff_duty_counts,i))
);
constraint forall(i in DAYS, j in ASSIGNMENTS) (
    ward_shift_manpower[i,j] = card(ward[i,j])
);

% Rule feature toggle constraints
constraint active_constraints[WardReqDuty] -> rules1();
constraint active_constraints[ContractDayOff] -> rules2();
constraint active_constraints[WeekendOff] -> rules3();
%constraint active_constraints[NoWeekendPP] -> rules4();
constraint active_constraints[MinWardStaffReq] -> rules5();
constraint active_constraints[NormalDutyStateDiagram] -> rules6();
constraint active_constraints[NormalNightFrequency] -> rules7();
constraint active_constraints[CallNightDuty] -> rules8();
constraint active_constraints[NormalOffFrequency] -> rules9();
%constraint active_constraints[ReqAnnualLeaves] -> rules10();
%constraint active_constraints[LongNightDuties] -> rules11();
constraint active_constraints[PublicHolidayOff] -> rules12();
constraint active_constraints[WardDayDuty] -> rules13();

% Rule 1: constraint of matching roster with WARD_REQ_DUTIES
predicate rules1 = forall(i in STAFFS, j in DAYS, k in DUTIES where has_element((i,j,k), WARD_REQ_DUTIES)) (
    assignment_to_duty(roster[i,j]) == k
);

% Rule 2: constraint of # of Os (contract + public holidays) for every nurse in a month
int: min_O_count = nCO + nPHs;
int: max_O_count = nDays;
predicate rules2 = (forall(i in STAFFS) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in global_cardinality([assignment_to_duty(temp[j]) | j in C(1..nRosterDays)], OFF, [min_O_count], [max_O_count])
));

% Rule 3: constraint of min # of contract Os for every teacher
int: min_weekend_O = round(card(DAYS) div 15);
predicate rules3 = (forall(i in STAFFS) (
    global_cardinality([assignment_to_duty(roster[i,j]) | j in C(1..nRosterDays)], OFF, [min_weekend_O], [nWeekends])
));

% Rule 4: constraint of no both-P for the same weekend
predicate rules4 = (forall(i in STAFFS) (
    forall(j in weekends where enum_next(j) in weekends) (
        roster[i,j] == P -> roster[i,enum_next(j)] != P
    )
));

% Rule 5: constraint of min # of staffs of all types in every N/A/P duties
predicate rules5 = (forall(i in DAYS) (
    global_cardinality(col(roster,i), ASSIGNMENTS, MIN_WARD, MAX_WARD)
));

% Rule 6: constraint of normal N requirement
int: Q1 = 2;
int: q0 = 1;
set of int: STATE1 = 1..Q1;
array[STATE1, DUTIES] of int: t1 = 
  [| 2, 1, 1, 1, 1      % state 1 (allow N at the 1st day)
   | 0, 0, 0, 1, 0 |];  % state 2 (can only have O)
predicate rules6 = (forall(i in STAFFS where not (i in CLASS_STAFFS[NIGHT])) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in regular([assignment_to_duty(temp[j]) | j in DAYS], Q1, nDuties, t1, q0, STATE1)
));

% Rule 7: constraint of 2Os for consecutive 4Ns in a row
int: Q2 = 6;
set of int: STATE2 = 1..Q2;
array[STATE2, DUTIES] of int: t2 = 
  [| 2, 0, 0, 1, 0      % state 1
   | 3, 0, 0, 1, 0      % state 2
   | 4, 0, 0, 1, 0      % state 3 
   | 5, 0, 0, 1, 0      % state 4
   | 0, 0, 0, 6, 0      % state 5 (cannot N again)
   | 0, 0, 0, 1, 0 |];  % state 6 (cannot N again)
predicate rules7 = (forall(i in CLASS_STAFFS[NIGHT]) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in regular([assignment_to_duty(temp[j]) | j in DAYS], Q2, nDuties, t2, q0, STATE2)
));

% Rule 8: constraint of call night then O
predicate rules8 = (forall(i in DAYS where i in call_req_duties /\ enum_next(i) in DAYS) (
    let {
        array[STAFFS] of var ASSIGNMENTS0: today = col(roster,i),
        array[STAFFS] of var ASSIGNMENTS0: tomorrow = col(roster,enum_next(i))
    } in occurs(call[i]) /\ assignment_to_duty(today[deopt(call[i])]) == P /\ assignment_to_duty(tomorrow[deopt(call[i])]) == O
));

% Rule 9: constraint of at least 1 O for every nurse in every consecutive MW days
int: Q4 = MW;
set of int: STATE4 = 1..Q4;
array[STATE4,DUTIES] of int: t4 = array2d(STATE4, DUTIES, [if j == O then q0 else i endif | i in 2..MW, j in DUTIES] ++
                                                          [0,0,0,q0,0]);
predicate rules9 = (forall(i in STAFFS where not (i in CLASS_STAFFS[NIGHT])) (
    let {
        array[DAYS] of var ASSIGNMENTS0: temp = row(roster,i)
    } in regular([assignment_to_duty(temp[j]) | j in DAYS], Q4, nDuties, t4, q0, STATE4)
));

% Rule 10: constraint of staff entitled annual leaves
%predicate rules10 = forall(i in STAFFS, j in DAYS) (
%    is_annual_leave[i,j] -> roster[i,j] == O
%);

% Rule 11: constraint of requested long night duties   
%array[STAFFS, DAYS] of opt DUTIES: long_night_duties = 
%    array2d(STAFFS, DAYS, [get_long_night_duty(i,j) | i in STAFFS, j in DAYS]);
%function opt DUTIES: get_long_night_duty(STAFFS: s, DAYS: d) =
%    let {
%        int: row = long_night_row(s, d),
%        int: day_offset = d - if row > 0 then long_nights[row,2] else 0 endif + 1
%    } in if row == 0 then <> else to_enum(DUTIES, long_nights[row, 2 + day_offset]) endif;
%predicate rules11 = forall(i in STAFFS, j in DAYS) (
%    occurs(long_night_duties[i,j]) -> roster[i,j] == long_night_duties[i,j]
%);

% Rule 12: constraint of >=1 public holiday Os for every nurse in a month if # of public holidays >= 3
int: min_ph_O = round((nPHs-1)/3);
predicate rules12 = (forall(i in STAFFS) (
    global_cardinality([assignment_to_duty(roster[i,j]) | j in public_holidays], OFF, [min_ph_O], [nPHs])
));

% Rule 13: constraint of D duty must appear in WARD_REQ_DUTIES
predicate rules13 = forall(i in STAFFS, j in DAYS) (
    assignment_to_duty(roster[i,j]) == D -> has_element((i,j,D), WARD_REQ_DUTIES)
);

% Objective functions
%var int: score1 = sum([not home_class_assigned(i,roster[i,j]) | i in STAFFS, j in DAYS]);
var int: score2 = sum(i in STAFFS) (count_subseq([assignment_to_duty(roster[i,j]) | j in DAYS], [O, N, O, N]));
var int: score3 = sum(i in STAFFS) (count_subseq([assignment_to_duty(roster[i,j]) | j in DAYS], [O, N, N, N, O, N]));
var int: score4 = length(STAFF_REQ_DUTIES) - sum(i in STAFFS, j in DAYS, k in DUTIES where (i,j,k) in STAFF_REQ_DUTIES) (assignment_to_duty(roster[i,j]) == k);
var int: score5 = sum(i in SHIFTS) (max_diff_shifts([col(staff_duty_counts,i)[j] | j in STAFFS where not (j in CLASS_STAFFS[NIGHT])]));
var int: score6 = sum(i in STAFFS) (diff_ap(staff_duty_counts[i,A], staff_duty_counts[i,P]));
var int: score7 = sum(i in ASSIGNMENTS) (max_diff_manpower(col(ward_shift_manpower,i)));

solve :: int_search(roster, first_fail, indomain_min) minimize /*score1 +*/ score2 + score3 + score4 + score5 + score6 + score7;

% Helper functions
function var DUTIES: assignment_to_duty(var ASSIGNMENTS0: index) = allAssignments[index].duty;
function var CLASSES: assignment_to_class(var ASSIGNMENTS0: index) = to_enum(CLASSES, allAssignments[index].place);
function var bool: home_class_assigned(STAFFS: staff, var ASSIGNMENTS0: index) = staff in CLASS_STAFFS[assignment_to_class(index)];

function WEEKDAYS: weekday(DAYS: day) = 
    let {
        int: temp = (enum2int(day) - enum2int(C(1)) + enum2int(MONTH_START)) mod 7
    } in 
    to_enum(WEEKDAYS, if temp <= 0 then temp + 7 else temp endif);

function string: format_duty(STAFFS: staff, DAYS: day) = 
    let {
        array[DUTIES] of bool: temp = [(staff,day,i) in STAFF_REQ_DUTIES | i in DUTIES],
        DUTIES: duty = fix(assignment_to_duty(roster[staff,day]))
    } in
    if xorall(temp) /\ not ((staff,day,duty) in STAFF_REQ_DUTIES) then lowercase[duty] elseif fix(call[day]) == staff then "C" else format(duty) endif;
    /*if temp[duty] then format(duty) elseif xorall(temp) then lowercase[duty] else " " endif;*/

function string: format_class(STAFFS: staff, DAYS: day) = 
    let {
        ASSIGNMENTS0: assignment = fix(roster[staff,day])
    } in if assignment in ASSIGNMENTS then shortform[fix(assignment_to_class(assignment))] else " " endif;

function array[int] of int: convert(array[int, int] of int: input) = 
    let {
        array[SHIFTS, MINS] of int: temp = array2d(SHIFTS, MINS, input)
    } in [temp[i,k] | i in SHIFTS where i != N, j in CLASSES where j != NIGHT, k in MINS where (j,k) in CLASS_MINS] ++ [temp[N,night]];

function array[int] of ReqDuties: req_duties(array[int, int] of int: input) = 
    [(to_enum(STAFFS, input[i,1]), 
      to_enum(DAYS, input[i,2]), 
      to_enum(DUTIES, input[i,3])) | i in 1..length(col(input,1))];

function var int: max_diff_shifts(array[int] of var int: input) = max(input) - min(input);

function var int: diff_ap(var int: a, var int: p) = 
    let {
        var int: temp = abs(a-p)
    } in 
    if (a+p) mod 2 == 1 /\ temp == 1 then 0 else temp endif;
    
function var int: max_diff_manpower(array[DAYS] of var int: input) = max(input) - min(input); 

function var int: count_subseq(array[int] of var DUTIES: main, array[int] of DUTIES: pat) =
    let { int: m = length(main),
          int: n = length(pat)
    } in if n > m then 0 else sum(i in 1..m-n+1) (forall(j in 1..n)(main[i+j-1] == pat[j])) endif;

% Verify data input and derived parameters
output ["Whole calendar: "] ++ [show(i) ++ " " | i in DAYS] ++ ["\n"];
output ["Whole calendar: "] ++ [show(DAY_WEEKDAYS)] ++ ["\n"];
output ["Available weekends: "] ++ [show(weekends)] ++ ["\n"];
output ["Available teachers: "] ++ [show(card(CLASS_STAFFS[i])) ++ " " | i in CLASSES] ++ ["\n"];
output [show(length(STAFF_REQ_DUTIES)) ++ " STAFF_REQ_DUTIES: \n"] ++ [show(STAFF_REQ_DUTIES)] ++ ["\n"];
output [show(length(WARD_REQ_DUTIES)) ++ " WARD_REQ_DUTIES: \n"] ++ [show(WARD_REQ_DUTIES)] ++ ["\n"];

% Result printing
output["\t" ++ join(" ",[if i in {C(1),X(1)} then "1" else " " endif | i in DAYS]) ++ "\t\t\t\t\t\t\t" ++ 
                join(" ",[if i in {C(1),X(1)} then "1" else " " endif | i in DAYS]) ++ "\n"];
output["\t" ++ join(" ",[if i in weekends then "S" else " " endif | i in DAYS]) ++ "\t" ++ join("\t",[show(i) | i in DUTIES]) ++ 
       "\t\t" ++ join(" ",[if i in weekends then "S" else " " endif | i in DAYS]) ++ "\n"];
output[show(i) ++ "\t" ++ join(" ",[format_duty(i,j) | j in DAYS]) ++ "\t" ++ join("\t",[show(fix(staff_duty_counts[i,j])) | j in DUTIES]) ++ "\t" ++
        show(i) ++ "\t" ++ join(" ",[format_class(i,j) | j in DAYS]) ++ "\n" | i in STAFFS];
output[/*"# of non-home class assignments = " ++ show(fix(score1)) ++*/ "\t# of ONONs= " ++ show(fix(score2)) ++ "\t# of ONNNONs= " ++ show(fix(score3)) ++ "\n"];
output["# of re-duty non-fulfillments= " ++ show(fix(score4)) ++ "\n"];
output["Total # of max shift diffs= " ++ show(fix(score5)) ++ "\tTotal # of A/P diffs= " ++ show(fix(score6)) ++"\n"];
output["Total # of max ward manpower diffs= " ++ show(fix(score7)) ++"\n"];
