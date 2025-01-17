USE [master]
GO
/****** Object:  Database [School]    Script Date: 2/13/2024 9:22:48 PM ******/
CREATE DATABASE [School]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'School', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\School.mdf' , SIZE = 4096KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'School_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\School_log.ldf' , SIZE = 12352KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
ALTER DATABASE [School] SET COMPATIBILITY_LEVEL = 110
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [School].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [School] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [School] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [School] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [School] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [School] SET ARITHABORT OFF 
GO
ALTER DATABASE [School] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [School] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [School] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [School] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [School] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [School] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [School] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [School] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [School] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [School] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [School] SET  DISABLE_BROKER 
GO
ALTER DATABASE [School] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [School] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [School] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [School] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [School] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [School] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [School] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [School] SET RECOVERY FULL 
GO
ALTER DATABASE [School] SET  MULTI_USER 
GO
ALTER DATABASE [School] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [School] SET DB_CHAINING OFF 
GO
ALTER DATABASE [School] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [School] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
EXEC sys.sp_db_vardecimal_storage_format N'School', N'ON'
GO
USE [School]
GO
/****** Object:  StoredProcedure [dbo].[AddCourseLesson]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[AddCourseLesson] @CourseID int, @DayOfTheWeek nvarchar(16), @LessonStart time, @LessonEnd time, @StartDate date, @EndDate date,
@RoomID int
AS
--Znalezienie pierwszego 'dobrego dnia'
WHILE(DATENAME(DW,@StartDate) != @DayOfTheWeek)
BEGIN
	SET @StartDate = DATEADD(day, 1, @StartDate)
END
IF @StartDate <= @EndDate
BEGIN
	INSERT INTO CourseDetails(CourseID, StartDate, EndDate, RoomID) SELECT @CourseID, CAST(F.StartDate as datetime) + CAST(@LessonStart as datetime),
	CAST(F.StartDate as datetime) + CAST(@LessonEnd as datetime), @RoomID
	FROM dbo.GenerateDatesInteval(@StartDate, @EndDate, 7) F;
END

GO
/****** Object:  StoredProcedure [dbo].[CourseGrades]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CourseGrades] @StudentID int, @CourseID int
AS
	SELECT G.*, (SELECT AG.Average FROM AverageGrades AG WHERE AG.PersonID = @StudentID AND AG.CourseID = @CourseID) AS [Average]
	FROM Grade G
	WHERE G.StudentID = @StudentID AND G.CourseID = @CourseID

GO
/****** Object:  StoredProcedure [dbo].[StudentCompleted]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[StudentCompleted] @StudentID int
AS
SELECT S.PersonID, P.FirstName, P.LastName, C.AcademicYear, SB.Name, TC.FinalMark FROM Student S
JOIN TakenCourse TC ON S.PersonID = TC.StudentID
JOIN Course C ON C.CourseID = TC.CourseID
JOIN [Subject] SB ON C.SubjectID = SB.SubjectID
JOIN Person P ON S.PersonID = P.PersonID
WHERE TC.FinalMark IS NOT NULL
AND S.PersonID = @StudentID

GO
/****** Object:  StoredProcedure [dbo].[StudentFamily]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[StudentFamily] @StudentID int
AS
	DECLARE @ParentID int;
	SET @ParentID = (SELECT S.ParentID FROM Student S WHERE S.PersonID = @StudentID);

		SELECT P.*, 'Student' as Relation FROM Student S 
		JOIN Person P ON P.PersonID = S.PersonID
		WHERE S.ParentID = @ParentID
	UNION
		SELECT P.*, 'Parent' as Relation FROM Person P
		WHERE P.PersonID = @ParentID
		ORDER BY Relation;

GO
/****** Object:  StoredProcedure [dbo].[StudentSchedule]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[StudentSchedule] @StudentID int, @StartDate datetime, @EndDate datetime
AS
SET @EndDate = DATEADD(day, 1, @EndDate);--zwiekszam o jeden dzien, i teraz tu będzie jeden dzien pozniej, ale godzina 00:00:00
SELECT * FROM Student S
JOIN TakenCourse TC ON S.PersonID = TC.StudentID
JOIN Course C ON C.CourseID = TC.CourseID
JOIN CourseDetails CD ON CD.CourseID = C.CourseID
WHERE TC.FinalMark IS NULL --jeszcze nie ma oceny końcowej więc to oznacza, że kurs się jeszcze nie zakończył czyli powinien być w planie lekcji
AND S.PersonID = @StudentID
AND CD.StartDate >= @StartDate AND CD.StartDate < @EndDate;

GO
/****** Object:  UserDefinedFunction [dbo].[AvailableHours]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[AvailableHours]
(@RoomID int, @GivenDate date)
RETURNS @TempTable TABLE
(
	CourseID int,
	StartDate datetime,
	EndDate datetime
)
AS
BEGIN
	INSERT INTO @TempTable 
		SELECT CD.CourseID, CD.StartDate, CD.EndDate FROM CourseDetails CD 
		WHERE CD.RoomID = @RoomID AND CD.StartDate >= @GivenDate AND CD.StartDate < dateadd(day,1,@GivenDate)
	RETURN
END

GO
/****** Object:  UserDefinedFunction [dbo].[AverageFinalMarks]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[AverageFinalMarks]
(@StudentID int)
RETURNS int
AS
BEGIN
	RETURN (SELECT AVG(TC.FinalMark) FROM TakenCourse TC WHERE TC.StudentID = @StudentID AND TC.FinalMark IS NOT NULL GROUP BY TC.StudentID)
END

GO
/****** Object:  Table [dbo].[AcademicYear]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AcademicYear](
	[AcademicYear] [nchar](9) NOT NULL,
 CONSTRAINT [PK_AcademicYear] PRIMARY KEY CLUSTERED 
(
	[AcademicYear] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Course]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Course](
	[CourseID] [int] IDENTITY(1,1) NOT NULL,
	[SubjectID] [int] NOT NULL,
	[TeacherID] [int] NOT NULL,
	[AcademicYear] [nchar](9) NOT NULL,
 CONSTRAINT [PK_Lesson_1] PRIMARY KEY CLUSTERED 
(
	[CourseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CourseDetails]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CourseDetails](
	[CourseDetailsID] [int] IDENTITY(1,1) NOT NULL,
	[CourseID] [int] NOT NULL,
	[StartDate] [datetime] NOT NULL,
	[EndDate] [datetime] NOT NULL,
	[RoomID] [int] NOT NULL,
 CONSTRAINT [PK_CourseDetails] PRIMARY KEY CLUSTERED 
(
	[CourseDetailsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Grade]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Grade](
	[GradeID] [int] IDENTITY(1,1) NOT NULL,
	[StudentID] [int] NOT NULL,
	[CourseID] [int] NOT NULL,
	[Grade] [float] NOT NULL,
	[Description] [nvarchar](64) NULL,
 CONSTRAINT [PK_Grade] PRIMARY KEY CLUSTERED 
(
	[GradeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[GradeValue]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GradeValue](
	[Value] [float] NOT NULL,
 CONSTRAINT [PK_GradeValue_1] PRIMARY KEY CLUSTERED 
(
	[Value] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Parent]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Parent](
	[PersonID] [int] NOT NULL,
	[Email] [nchar](64) NULL,
 CONSTRAINT [PK_Parent] PRIMARY KEY CLUSTERED 
(
	[PersonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Person]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Person](
	[PersonID] [int] IDENTITY(1,1) NOT NULL,
	[FirstName] [nvarchar](64) NOT NULL,
	[LastName] [nvarchar](64) NOT NULL,
	[Gender] [nchar](1) NULL,
	[PESEL] [nchar](11) NOT NULL,
	[BirthDate] [date] NULL,
	[PhoneNumber] [nvarchar](16) NULL,
	[Street] [nvarchar](32) NULL,
	[City] [nvarchar](32) NULL,
	[PostalCode] [nchar](6) NULL,
 CONSTRAINT [PK_Person] PRIMARY KEY CLUSTERED 
(
	[PersonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UNIQUE_PESEL] UNIQUE NONCLUSTERED 
(
	[PESEL] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Room]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Room](
	[RoomID] [int] IDENTITY(1,1) NOT NULL,
	[Label] [nvarchar](8) NOT NULL,
	[Floor] [tinyint] NULL,
 CONSTRAINT [PK_Room] PRIMARY KEY CLUSTERED 
(
	[RoomID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Student]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Student](
	[PersonID] [int] NOT NULL,
	[ParentID] [int] NOT NULL,
	[DateOfAcceptance] [date] NOT NULL,
 CONSTRAINT [PK_Student] PRIMARY KEY CLUSTERED 
(
	[PersonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Subject]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Subject](
	[SubjectID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](64) NOT NULL,
	[ECTS] [tinyint] NOT NULL,
	[Description] [nvarchar](64) NULL,
 CONSTRAINT [PK_Subject] PRIMARY KEY CLUSTERED 
(
	[SubjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[TakenCourse]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TakenCourse](
	[CourseID] [int] NOT NULL,
	[StudentID] [int] NOT NULL,
	[FinalMark] [float] NULL,
 CONSTRAINT [PK_CurrentSubject] PRIMARY KEY CLUSTERED 
(
	[CourseID] ASC,
	[StudentID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Teacher]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Teacher](
	[PersonID] [int] NOT NULL,
	[HireDate] [date] NOT NULL,
	[Salary] [money] NOT NULL,
 CONSTRAINT [PK_Teacher] PRIMARY KEY CLUSTERED 
(
	[PersonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  UserDefinedFunction [dbo].[AvailableCourses]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[AvailableCourses]
(@AcademicYear varchar(64))
RETURNS TABLE
AS
RETURN (
		SELECT C.AcademicYear, P.FirstName as [Lecturer's Name], P.LastName [Lecturer's Surname], S.Name FROM Course C
		JOIN Subject S ON C.SubjectID = S.SubjectID 
		JOIN Teacher T ON C.TeacherID = T.PersonID 
		JOIN Person P ON T.PersonID = P.PersonID
		WHERE C.AcademicYear = @AcademicYear
	);

GO
/****** Object:  UserDefinedFunction [dbo].[GenerateDatesInteval]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GenerateDatesInteval] (@StartDate date, @EndDate date, @Interval tinyint)
RETURNS TABLE
AS
RETURN
(
	WITH MY_CTE
	AS
	(SELECT @StartDate StartDate
	UNION ALL
	SELECT DATEADD(day, @Interval, StartDate)
	FROM MY_CTE
	WHERE DATEADD(day, @Interval, StartDate) <= @EndDate
	)
	SELECT * FROM MY_CTE
)

GO
/****** Object:  UserDefinedFunction [dbo].[TeacherSalary]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[TeacherSalary]
(@Salary money)
RETURNS TABLE
AS
RETURN (
	SELECT P.FirstName, P.LastName, T.HireDate, T.Salary 
	FROM Teacher T JOIN Person P ON T.PersonID = P.PersonID
	WHERE T.Salary >= @Salary
)

GO
/****** Object:  View [dbo].[AverageGrades]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[AverageGrades]
AS
	SELECT S.PersonID, P.FirstName, P.LastName, G.CourseID, CAST(AVG(G.Grade) as decimal(10,2)) as [Average]
	FROM Student S
	JOIN Person P ON S.PersonID = P.PersonID
	JOIN TakenCourse TC ON S.PersonID = TC.StudentID
	JOIN Grade G ON TC.StudentID = G.StudentID AND TC.CourseID = G.CourseID
	GROUP BY S.PersonID, P.FirstName, P.LastName, G.CourseID;

GO
/****** Object:  View [dbo].[IdentifyPerson]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[IdentifyPerson]
AS
	SELECT P.FirstName, P.LastName,
	CASE 
		WHEN (SELECT S.PersonID FROM Student S WHERE S.PersonID = P.PersonID) IS NOT NULL THEN 'YES'
		ELSE 'NO'
	END AS [StudentCheck],
	CASE 
		WHEN (SELECT S.PersonID FROM Teacher S WHERE S.PersonID = P.PersonID) IS NOT NULL THEN 'YES'
		ELSE 'NO'
	END AS [TeacherCheck],
	CASE 
		WHEN (SELECT S.PersonID FROM Parent S WHERE S.PersonID = P.PersonID) IS NOT NULL THEN 'YES'
		ELSE 'NO'
	END AS [ParentCheck]
	FROM Person P;

GO
/****** Object:  View [dbo].[Lessons]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[Lessons]
AS
	SELECT C.AcademicYear, S.Name, COUNT(*) as NumberOfMeetings, SUM(DATEDIFF(minute, CD.StartDate, CD.EndDate))/60 as [Length (Hours)]
	FROM Course C JOIN CourseDetails CD ON C.CourseID = CD.CourseID
	JOIN Subject S ON C.SubjectID = S.SubjectID
	GROUP BY C.AcademicYear, S.Name;

GO
/****** Object:  View [dbo].[ParentChildren]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[ParentChildren]
AS
	SELECT Pinfo.FirstName [Parent FirstName], Pinfo.LastName [Parent LastName], Sinfo.FirstName [Child FirstName], Sinfo.LastName [Child LastName]
	FROM Parent P JOIN Person Pinfo ON P.PersonID = Pinfo.PersonID
	JOIN Student S ON P.PersonID = S.ParentID
	JOIN Person Sinfo ON Sinfo.PersonID = S.PersonID;

GO
/****** Object:  View [dbo].[TeachersInfo]    Script Date: 2/13/2024 9:22:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[TeachersInfo]
AS
SELECT P.PersonID, P.FirstName, P.LastName, T.Salary, T.HireDate, S.Name, C.AcademicYear
FROM Teacher T JOIN Person P ON T.PersonID = P.PersonID
JOIN Course C ON T.PersonID = C.TeacherID
JOIN [Subject] S ON C.SubjectID = S.SubjectID;

GO
ALTER TABLE [dbo].[Course]  WITH CHECK ADD  CONSTRAINT [FK_Course_AcademicYear] FOREIGN KEY([AcademicYear])
REFERENCES [dbo].[AcademicYear] ([AcademicYear])
GO
ALTER TABLE [dbo].[Course] CHECK CONSTRAINT [FK_Course_AcademicYear]
GO
ALTER TABLE [dbo].[Course]  WITH CHECK ADD  CONSTRAINT [FK_Course_Subject] FOREIGN KEY([SubjectID])
REFERENCES [dbo].[Subject] ([SubjectID])
GO
ALTER TABLE [dbo].[Course] CHECK CONSTRAINT [FK_Course_Subject]
GO
ALTER TABLE [dbo].[Course]  WITH CHECK ADD  CONSTRAINT [FK_Lesson_Teacher] FOREIGN KEY([TeacherID])
REFERENCES [dbo].[Teacher] ([PersonID])
GO
ALTER TABLE [dbo].[Course] CHECK CONSTRAINT [FK_Lesson_Teacher]
GO
ALTER TABLE [dbo].[CourseDetails]  WITH CHECK ADD  CONSTRAINT [FK_CourseDetails_Course] FOREIGN KEY([CourseID])
REFERENCES [dbo].[Course] ([CourseID])
GO
ALTER TABLE [dbo].[CourseDetails] CHECK CONSTRAINT [FK_CourseDetails_Course]
GO
ALTER TABLE [dbo].[CourseDetails]  WITH CHECK ADD  CONSTRAINT [FK_CourseDetails_Room] FOREIGN KEY([RoomID])
REFERENCES [dbo].[Room] ([RoomID])
GO
ALTER TABLE [dbo].[CourseDetails] CHECK CONSTRAINT [FK_CourseDetails_Room]
GO
ALTER TABLE [dbo].[Grade]  WITH CHECK ADD  CONSTRAINT [FK_Grade_GradeValue] FOREIGN KEY([Grade])
REFERENCES [dbo].[GradeValue] ([Value])
GO
ALTER TABLE [dbo].[Grade] CHECK CONSTRAINT [FK_Grade_GradeValue]
GO
ALTER TABLE [dbo].[Grade]  WITH CHECK ADD  CONSTRAINT [FK_Grade_TakenCourse] FOREIGN KEY([CourseID], [StudentID])
REFERENCES [dbo].[TakenCourse] ([CourseID], [StudentID])
GO
ALTER TABLE [dbo].[Grade] CHECK CONSTRAINT [FK_Grade_TakenCourse]
GO
ALTER TABLE [dbo].[Parent]  WITH NOCHECK ADD  CONSTRAINT [FK_Parent_Person] FOREIGN KEY([PersonID])
REFERENCES [dbo].[Person] ([PersonID])
NOT FOR REPLICATION 
GO
ALTER TABLE [dbo].[Parent] CHECK CONSTRAINT [FK_Parent_Person]
GO
ALTER TABLE [dbo].[Student]  WITH CHECK ADD  CONSTRAINT [FK_Student_Parent] FOREIGN KEY([ParentID])
REFERENCES [dbo].[Parent] ([PersonID])
GO
ALTER TABLE [dbo].[Student] CHECK CONSTRAINT [FK_Student_Parent]
GO
ALTER TABLE [dbo].[Student]  WITH CHECK ADD  CONSTRAINT [FK_Student_Person] FOREIGN KEY([PersonID])
REFERENCES [dbo].[Person] ([PersonID])
GO
ALTER TABLE [dbo].[Student] CHECK CONSTRAINT [FK_Student_Person]
GO
ALTER TABLE [dbo].[TakenCourse]  WITH CHECK ADD  CONSTRAINT [FK_TakenCourse_Course] FOREIGN KEY([CourseID])
REFERENCES [dbo].[Course] ([CourseID])
GO
ALTER TABLE [dbo].[TakenCourse] CHECK CONSTRAINT [FK_TakenCourse_Course]
GO
ALTER TABLE [dbo].[TakenCourse]  WITH CHECK ADD  CONSTRAINT [FK_TakenCourse_GradeValue] FOREIGN KEY([FinalMark])
REFERENCES [dbo].[GradeValue] ([Value])
GO
ALTER TABLE [dbo].[TakenCourse] CHECK CONSTRAINT [FK_TakenCourse_GradeValue]
GO
ALTER TABLE [dbo].[TakenCourse]  WITH CHECK ADD  CONSTRAINT [FK_TakenCourse_Student] FOREIGN KEY([StudentID])
REFERENCES [dbo].[Student] ([PersonID])
GO
ALTER TABLE [dbo].[TakenCourse] CHECK CONSTRAINT [FK_TakenCourse_Student]
GO
ALTER TABLE [dbo].[Teacher]  WITH CHECK ADD  CONSTRAINT [FK_Teacher_Person] FOREIGN KEY([PersonID])
REFERENCES [dbo].[Person] ([PersonID])
GO
ALTER TABLE [dbo].[Teacher] CHECK CONSTRAINT [FK_Teacher_Person]
GO
USE [master]
GO
ALTER DATABASE [School] SET  READ_WRITE 
GO
