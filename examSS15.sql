/*
 * DATABASE SETUP - SESSION 15 EXAM
 * Database: StudentManagement
 */

DROP DATABASE IF EXISTS StudentManagement;
CREATE DATABASE StudentManagement;
USE StudentManagement;

-- =============================================
-- 1. TABLE STRUCTURE
-- =============================================

-- Table: Students
CREATE TABLE Students (
    StudentID CHAR(5) PRIMARY KEY,
    FullName VARCHAR(50) NOT NULL,
    TotalDebt DECIMAL(10,2) DEFAULT 0
);

-- Table: Subjects
CREATE TABLE Subjects (
    SubjectID CHAR(5) PRIMARY KEY,
    SubjectName VARCHAR(50) NOT NULL,
    Credits INT CHECK (Credits > 0)
);

-- Table: Grades
CREATE TABLE Grades (
    StudentID CHAR(5),
    SubjectID CHAR(5),
    Score DECIMAL(4,2) CHECK (Score BETWEEN 0 AND 10),
    PRIMARY KEY (StudentID, SubjectID),
    CONSTRAINT FK_Grades_Students FOREIGN KEY (StudentID) REFERENCES Students(StudentID),
    CONSTRAINT FK_Grades_Subjects FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID)
);

-- Table: GradeLog
CREATE TABLE GradeLog (
    LogID INT PRIMARY KEY AUTO_INCREMENT,
    StudentID CHAR(5),
    OldScore DECIMAL(4,2),
    NewScore DECIMAL(4,2),
    ChangeDate DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 2. SEED DATA
-- =============================================

-- Insert Students
INSERT INTO Students (StudentID, FullName, TotalDebt) VALUES 
('SV01', 'Ho Khanh Linh', 5000000),
('SV03', 'Tran Thi Khanh Huyen', 0);

-- Insert Subjects
INSERT INTO Subjects (SubjectID, SubjectName, Credits) VALUES 
('SB01', 'Co so du lieu', 3),
('SB02', 'Lap trinh Java', 4),
('SB03', 'Lap trinh C', 3);

-- Insert Grades
INSERT INTO Grades (StudentID, SubjectID, Score) VALUES 
('SV01', 'SB01', 8.5), -- Passed
('SV03', 'SB02', 3.0); -- Failed

-- End of File

delimiter $$

create trigger tg_CheckScore
before insert on Grades
for each row
begin
	if new.Score < 0 THEN
        set new.Score = 0;
    elseif new.Score > 10 THEN
        set new.Score = 10;
    end if;
end $$

delimiter ;

start transaction;

insert into Students (StudentID, FullName)
values ('SV02', 'Ha Bich Ngoc');

update Students
set TotalDebt = 5000000
where StudentID = 'SV02';

commit;

select * from Students;

delimiter $$
create trigger tg_LogGradeUpdate
after update on Grades
for each row
begin
	insert into GradeLog (
		StudentID,
		OldScore,
		NewScore,
		ChangeDate
	)
	values (
		old.StudentID,
		old.Score,
		new.Score,
		now()
        );
end $$
delimiter ;

delimiter $$

create procedure sp_PayTuition()
begin
	declare p_TotalDept decimal(10, 2);
	
    start transaction;
    update Students
    set TotalDept = TotalDept - 2000000
    where StudentID = 'SV01';
    
    select TotalDept
    into  p_TotalDept
    from Students
    where StudentID = 'SV01';
    
    if p_TotalDept < 0 then
		rollback;
	else
		commit;
	end if;
    
end $$
delimiter ;

delimiter $$

create trigger tg_PreventPassUpdate
before update on Grades
for each row
begin
	if old.Score >= 4 then
		rollback;
        signal sqlstate '45000'
        set message_text = 'chưa tày đâu';
	end if;
end $$
delimiter ;

delimiter $$
create procedure sp_DeleteStudentGrade(
	in p_StudentID int ,
    in p_SubjectID int
)
begin
	declare v_oldscore decimal(4,2);
    
	start transaction;
    select Score
    into v_oldscore
    from Grades
    where Studentid = p_Sudentid
      and Subjectid = p_Subjectid
    limit 1;

    insert into Gradelog (
        Studentid,
        Subjectid,
        Oldscore,
        Newscore,
        Logdate
    )
    values (
        p_Studentid,
        p_Subjectid,
        v_oldscore,
        null,
        now()
    );

    delete from Grades
    where Studentid = p_Studentid
      and Subjectid = p_Subjectid;

    if row_count() = 0 then
        rollback;
    else
        commit;
    end if;
    
end $$
delimiter ;
