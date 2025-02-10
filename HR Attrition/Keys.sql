-- -- -- -- -- -- ADDING PRIMARY KEY -- -- -- -- -- -- 

-- Employee table  
ALTER TABLE "Employee"  
ADD CONSTRAINT pk_employee PRIMARY KEY ("EmployeeID");  
  
-- Education Level
ALTER TABLE "EducationLevel"  
ADD CONSTRAINT pk_educationlevel PRIMARY KEY ("EducationLevelID"); 

-- Performance Rating
ALTER TABLE "PerformanceRating"
ADD CONSTRAINT pk_performance PRIMARY KEY ("PerformanceID");

-- -- -- -- -- -- ADDING FOREIGN KEY -- -- -- -- -- -- 

-- PerformanceRating table referencing Employee table  
ALTER TABLE "PerformanceRating"  
ADD CONSTRAINT fk_performance_employee  
FOREIGN KEY ("EmployeeID")  
REFERENCES "Employee"("EmployeeID");  

-- Employee table referencing EducationLevel table  
ALTER TABLE "Employee"  
ADD CONSTRAINT fk_employee_educationlevel  
FOREIGN KEY ("Education")  
REFERENCES "EducationLevel"("EducationLevelID");