CREATE DATABASE Hospital;
USE Hospital;
SET FOREIGN_KEY_CHECKS=0;

#Tables
CREATE TABLE Patients(
    Patient_ID INT NOT NULL, 
    Last_Name TEXT,
    First_Name TEXT,
    Date_of_Birth TEXT,
    Gender TEXT,
    Room_ID INT NOT NULL,
    PRIMARY KEY (Patient_ID),
    FOREIGN KEY (Room_ID) REFERENCES Rooms(Room_ID)
);

CREATE TABLE Rooms(
    Room_ID INT NOT NULL,
    Room_Number INT,
    Department_ID INT NOT NULL,
    PRIMARY KEY (Room_ID),
    FOREIGN KEY (Department_ID) REFERENCES Departments(Department_ID)
);

CREATE TABLE Departments(
    Department_ID INT NOT NULL,
    Department_Name TEXT,
    PRIMARY KEY (Department_ID)
);

CREATE TABLE Nurses(
    Nurse_ID INT NOT NULL,
    Last_Name TEXT,
    First_Name TEXT,
    Department_ID INT NOT NULL,
    Supervisor_ID INT,
    PRIMARY KEY (Nurse_ID),
    FOREIGN KEY (Department_ID) REFERENCES Departments(Department_ID)
);

CREATE TABLE Diagnoses(
    Diagnoses_ID INT NOT NULL,
    Date_of_Diagnosis TEXT,
    Diagnosis_Result TEXT,
    PRIMARY KEY (Diagnoses_ID)
);

CREATE TABLE Medications(
    Medication_ID INT NOT NULL,
    Medication_Name TEXT,
    Dosage INT,
    PRIMARY KEY (Medication_ID)
);

CREATE TABLE Visits(
    Visit_ID INT NOT NULL,
    Visit_Date TEXT,
    Visit_Duration INT,
    PRIMARY KEY (Visit_ID)
);
#Tables

#M:N tables
CREATE TABLE Patients_Diagnoses(
    SELECT Patients.Patient_ID, Diagnoses.Diagnoses_ID
    FROM Patients
    INNER JOIN Diagnoses ON Patients.Patient_ID = Diagnoses.Diagnoses_ID
);

CREATE TABLE Patients_Medications(
    SELECT Patients.Patient_ID, Medications.Medication_ID
    FROM Patients
    INNER JOIN Medications ON Patients.Patient_ID = Medications.Medication_ID
);

CREATE TABLE Patients_Visits(
    SELECT Patients.Last_Name, Visits.Visit_Date, Visits.Visit_Duration 
    FROM Patients
    INNER JOIN Visits ON Patients.Patient_ID = Visits.Visit_ID
);
#M:N tables

#Joining three tables
CREATE TABLE ThreeTables(
    SELECT Patients.First_Name, Patients.Last_Name, Visits.Visit_Date, Visits.Visit_Duration
    FROM Patients_Visits
    INNER JOIN Patients ON Patients_Visits.Patient_ID = Patients.Patient_ID
    LEFT JOIN Visits ON Patients_Visits.Visit_ID = Visits.Visit_ID
);

CREATE TABLE ThreeTables2(
    SELECT Patients.First_Name, Patients.Last_Name, Medications.Medication_Name, Medications.Dosage
    FROM Patients_Medications AS pm
    INNER JOIN Patients ON pm.Patient_ID = Patients.Patient_ID
    LEFT JOIN Medications ON pm.Medication_ID = Medications.Medication_ID
    WHERE Medications.Dosage = 1
);

CREATE TABLE ThreeTables3(
    SELECT p.Last_Name, p.First_Name, d.Diagnosis_Result, d.Date_of_Diagnosis
    FROM Patients_Diagnoses AS pd
    RIGHT JOIN Patients AS p ON pd.Patient_ID = p.Patient_ID
    LEFT JOIN Diagnoses AS d ON pd.Diagnoses_ID = d.Diagnoses_ID
);

CREATE TABLE ThreeTables4(
    SELECT Rooms.Room_Number, Nurses.Last_Name, Nurses.First_Name
    FROM Departments AS d
    INNER JOIN Rooms ON d.Department_ID = Rooms.Room_ID
    LEFT JOIN Nurses ON d.Department_ID = Nurses.Nurse_ID
);
#Joining three tables

#The average number of zaznamu per table
SELECT AVG(table_rows) AS avg_row_count FROM information_schema.tables WHERE table_schema = 'Hospital';
#The average number of zaznamu per table

#The hierarchy of nurses
WITH RECURSIVE NursesHierarchy AS (
    SELECT Nurse_ID, Last_Name, First_Name, Department_ID, Supervisor_ID, 1 AS Level
    FROM Nurses
    WHERE Supervisor_ID IS NULL
   
   UNION ALL
   
   SELECT n.Nurse_ID, n.Last_Name, n.First_Name, n.Department_ID, n.Supervisor_ID, nh.Level + 1
    FROM Nurses n
    JOIN NursesHierarchy nh ON n.Supervisor_ID = nh.Nurse_ID
)
#The hierarchy of nurses

#View of three tables
CREATE VIEW patient_info AS
SELECT
    Pa.Patient_ID, Pa.Last_Name, Pa.First_Name, Pa.Date_of_Birth, Pa.Gender, Ro.Room_Number, D.Department_Name, V.Visit_Date, V.Visit_Duration
FROM
    Patients AS Pa
INNER JOIN
    Rooms AS Ro ON Pa.room_ID = Ro.Room_ID
LEFT JOIN
    Departments AS D ON Ro.Department_ID = D.Department_ID
LEFT JOIN
    Visits AS V ON Pa.Patient_ID = V.Visit_ID;
#View of three tables


#Index for medication
CREATE unique INDEX medication_index on Medications(Medication_Name(1));
#Index for medication


#Function for counting how many visits there are for a certain length (minutes) of visits
DELIMITER $$

CREATE FUNCTION count_visits(duration INT) RETURNS INT DETERMINISTIC
BEGIN
    DECLARE count INT;
    SELECT COUNT(*) INTO count FROM Visits
    WHERE Visit_Duration >= duration;
    RETURN count;
END $$

DELIMITER ;
#Function for counting how many visits are there for the certain length (minutes) of visits


#Procedure for generating random visits for patients
DELIMITER $$

CREATE PROCEDURE GenerateRandomVisits()
BEGIN

    DECLARE visit_date DATE;
    DECLARE visit_duration INT;
    DECLARE i INT DEFAULT 0;
    
    CREATE TABLE IF NOT EXISTS NewVisits (
        Patient_ID INT,
        Visit_Date DATE,
        Visit_Duration INT,
        FOREIGN KEY (Patient_ID) REFERENCES Patients(Patient_ID)
    );
    
    WHILE i < 10 DO
    
        SET visit_date = CURRENT_DATE() + INTERVAL FLOOR(RAND() * 30) DAY;
        
        SET visit_duration = FLOOR(RAND() * (60 + 1)) + 30;

        INSERT INTO NewVisits (Patient_ID, Visit_Date, Visit_Duration)
        VALUES (FLOOR(RAND() * 20) + 1, visit_date, visit_duration);

        SET i = i + 1;
    END WHILE;
END $$

DELIMITER ;

CALL GenerateRandomVisits();
#Procedure for generating random visits for patients


#Trigger for the table Aid
DELIMITER $$

CREATE TRIGGER medication_changes
AFTER UPDATE ON Medications
FOR EACH ROW
BEGIN
    IF OLD.Dosage != NEW.Dosage THEN
        INSERT INTO medication_changes(Medication_ID, Name, Dosage_before, Dosage_after, Change_Time) VALUES (OLD.Medication_ID, OLD.Medication_Name, OLD.Dosage, NEW.Dosage, CURRENT_TIMESTAMP());
    END IF;
END $$
DELIMITER ;

CREATE TABLE medication_changes(
    Medication_ID INT,
    Name TEXT,
    Dosage_before INT,
    Dosage_after INT,
    Change_Time DATETIME,
    FOREIGN KEY (Medication_ID) REFERENCES Medications(Medication_ID)
);
#Trigger for the Medications table

#Transactions of units in the inventory
DELIMITER $$

CREATE PROCEDURE TakeDosage(IN medicationID INT, IN desiredDosage INT)
BEGIN

    DECLARE currentDosage INT;
    
    DECLARE medications_Cursor CURSOR FOR
    SELECT Dosage FROM Medications WHERE Medication_ID = medicationID;
    
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND
    BEGIN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nonexistent record for the given medication.';
    END;

    START TRANSACTION;

    OPEN medications_Cursor;

    FETCH medications_Cursor INTO currentDosage;

    IF currentDosage IS NULL OR currentDosage < desiredDosage THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient medication dosage.';
    ELSE
        UPDATE Medications SET Dosage = Dosage - desiredDosage WHERE Medication_ID = medicationID;
        COMMIT;
    END IF;
    CLOSE medications_Cursor;
END $$

DELIMITER ;

CALL TakeDosage(20,1);
#Transactions of units in the inventory


#User and roles
CREATE USER 'Hamza'@'localhost' IDENTIFIED BY 'admin123';
DROP USER 'Admin'@'localhost';

SELECT User, Host FROM mysql.user;

CREATE ROLE 'admin';
GRANT SELECT, INSERT, UPDATE ON Hospital.* TO 'admin';
DROP ROLE 'admin';

GRANT 'admin' TO 'Hamza'@'localhost';
REVOKE SELECT, INSERT, UPDATE ON Hospital.* FROM 'admin';
#User and roles

#Locking and unlocking tables
LOCK TABLE Medications READ;
UNLOCK TABLES;
#Locking and unlocking tables


#Data for the tables
INSERT INTO Patients (Patient_ID, Last_Name, First_Name, Date_of_Birth, Gender, room_ID)
VALUES
  (1, 'Novak', 'Jan', '1980-05-10', 'Male', 1),
  (2, 'Svoboda', 'Marie', '1995-08-15', 'Female', 2),
  (3, 'Prochazka', 'Petr', '1972-12-03', 'Male', 3),
  (4, 'Kovarova', 'Katerina', '1988-02-20', 'Female', 1),
  (5, 'Mares', 'Jiri', '1990-07-18', 'Male', 4),
  (6, 'Vesely', 'Eva', '1985-04-25', 'Female', 3),
  (7, 'Cerny', 'Lukas', '1978-09-08', 'Male', 2),
  (8, 'Kralova', 'Tereza', '1992-11-12', 'Female', 1),
  (9, 'Bartos', 'Michael', '1983-06-30', 'Male', 4),
  (10, 'Pospisilova', 'Lucie', '1997-03-07', 'Female', 3),
  (11, 'Dvorak', 'Martin', '1987-10-15', 'Male', 2),
  (12, 'Nemcova', 'Alena', '1991-09-22', 'Female', 1),
  (13, 'Kucera', 'Tomas', '1975-08-05', 'Male', 4),
  (14, 'Novotna', 'Marketa', '1989-07-02', 'Female', 3),
  (15, 'Pokorny', 'Jan', '1982-04-19', 'Male', 2),
  (16, 'Mala', 'Anna', '1993-12-28', 'Female', 1),
  (17, 'Sykora', 'David', '1979-11-11', 'Male', 4),
  (18, 'Krizova', 'Petra', '1996-10-14', 'Female', 3),
  (19, 'Havlicek', 'Milan', '1981-03-03', 'Male', 2),
  (20, 'Bila', 'Katerina', '1994-06-16', 'Female', 1);

INSERT INTO Rooms (Room_ID, Room_Number, Department_ID)
VALUES
  (1, 101, 1),
  (2, 102, 1),
  (3, 103, 2),
  (4, 104, 2),
  (5, 105, 3),
  (6, 106, 3),
  (7, 107, 1),
  (8, 108, 1),
  (9, 109, 2),
  (10, 110, 2),
  (11, 111, 3),
  (12, 112, 3),
  (13, 113, 1),
  (14, 114, 1),
  (15, 115, 2),
  (16, 116, 2),
  (17, 117, 3),
  (18, 118, 3),
  (19, 119, 1),
  (20, 120, 1);
  
INSERT INTO Departments(Department_ID, Department_Name)
VALUES
  (1, 'Surgery'),
  (2, 'Cardiology'),
  (3, 'Neurology'),
  (4, 'Gynecology'),
  (5, 'Orthopedics'),
  (6, 'Pediatrics'),
  (7, 'Oncology'),
  (8, 'Ophthalmology'),
  (9, 'Urology'),
  (10, 'Dermatology'),
  (11, 'Psychiatry'),
  (12, 'Endocrinology'),
  (13, 'Gastroenterology'),
  (14, 'Nephrology'),
  (15, 'Radiology'),
  (16, 'Hematology'),
  (17, 'Pulmonology'),
  (18, 'Immunology'),
  (19, 'Rehabilitation'),
  (20, 'Infectious Diseases Department');

INSERT INTO Nurses(Nurse_ID, Last_Name, First_Name, Department_ID, Supervisor_ID)
VALUES
    (1, 'Nováková', 'Alžběta', 1, NULL),
    (2, 'Kučerová', 'Božena', 2, 1),
    (3, 'Procházková', 'Clara', 1, NULL),
    (4, 'Svobodová', 'David', 2, 1),
    (5, 'Malá', 'Eva', 3, 2),
    (6, 'Černý', 'František', 4, 2),
    (7, 'Havlíčková', 'Gabriela', 3, 2),
    (8, 'Dvořáková', 'Hynek', 5, 1),
    (9, 'Zemanová', 'Irena', 4, 1),
    (10, 'Tůmová', 'Jiří', 5, 1),
    (11, 'Šimonová', 'Klára', 2, 1), 
    (12, 'Richterová', 'Leoš', 4, 2),    
    (13, 'Konečná', 'Mia', 3, 3),           
    (14, 'Fialová', 'Nathan', 4, 2),           
    (15, 'Horáková', 'Olga', 5, 2),           
    (16, 'Křížová', 'Pavel', 2, 2),           
    (17, 'Veselá', 'Quinn', 4, 2),            
    (18, 'Kučerová', 'Richard', 3, 3),       
    (19, 'Bartošová', 'Sophia', 5, 3),        
    (20, 'Pospíšilová', 'Tomáš', 2, 1);
    
INSERT INTO Diagnoses (Diagnoses_ID, Date_of_Diagnosis, Diagnosis_Result)
VALUES
  (1, '2023-03-15', 'Hypertension'),
  (2, '2023-02-28', 'Fractured Leg'),
  (3, '2023-03-12', 'Angina Pectoris'),
  (4, '2023-03-10', 'Infectious Disease'),
  (5, '2023-03-05', 'Migraine'),
  (6, '2023-03-20', 'Pneumonia'),
  (7, '2023-02-25', 'Allergic Reaction'),
  (8, '2023-03-08', 'Diabetes Mellitus'),
  (9, '2023-03-18', 'Chronic Bronchitis'),
  (10, '2023-02-27', 'Gastritis'),
  (11, '2023-03-14', 'Depression'),
  (12, '2023-03-03', 'Acute Pyelonephritis'),
  (13, '2023-03-22', 'Rheumatoid Arthritis'),
  (14, '2023-03-07', 'Gastroesophageal Reflux Disease'),
  (15, '2023-02-26', 'Appendicitis'),
  (16, '2023-03-11', 'Hepatitis'),
  (17, '2023-03-17', 'Asthma'),
  (18, '2023-03-02', 'Diabetes'),
  (19, '2023-03-16', 'Hyperlipidemia'),
  (20, '2023-03-19', 'Stroke');
  
INSERT INTO Medications (Medication_ID, Medication_Name, Dosage)
VALUES
	(1, 'Losartan', 5),
	(2, 'Paracetamol', 2),
	(3, 'Ibuprofen', 1),
	(4, 'Amoxicillin', 3),
	(5, 'Sumatriptan', 2),
	(6, 'Azithromycin', 1),
	(7, 'Loratadine', 1),
	(8, 'Insulin', 1),
	(9, 'Albuterol', 2),
	(10, 'Omeprazole', 2),
	(11, 'Sertraline', 3),
	(12, 'Ciprofloxacin', 5),
	(13, 'Prednisone', 5),
	(14, 'Escitalopram', 4),
	(15, 'Salbutamol', 1),
	(16, 'Simvastatin', 2),
	(17, 'Metformin', 5),
	(18, 'Rivotril', 2),
	(19, 'Nitroglycerin', 2),
	(20, 'Acetylsalicylic Acid', 3);
	  
INSERT INTO Visits (Visit_ID, Visit_Date, Visit_Duration)
VALUES
  (1, '2023-05-26', 60),
  (2, '2023-05-27', 45),
  (3, '2023-05-28', 30),
  (4, '2023-05-29', 90),
  (5, '2023-05-30', 120),
  (6, '2023-05-31', 75),
  (7, '2023-06-01', 60),
  (8, '2023-06-02', 45),
  (9, '2023-06-03', 30),
  (10, '2023-06-04', 90),
  (11, '2023-06-05', 120),
  (12, '2023-06-06', 75),
  (13, '2023-06-07', 60),
  (14, '2023-06-08', 45),
  (15, '2023-06-09', 30),
  (16, '2023-06-10', 90),
  (17, '2023-06-11', 120),
  (18, '2023-06-12', 75),
  (19, '2023-06-13', 60),
  (20, '2023-06-14', 45);
#Data for the tables