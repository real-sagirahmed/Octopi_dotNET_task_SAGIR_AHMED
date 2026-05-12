/*
# SQL Server Stored Procedures Assessment Report

This document contains the implementation and execution details for the Task stored procedures based on the `DCN-Miju` database.

-------------------------------------------------------------------------------

## Question 1
Write a stored procedure named usp_GetEmployeeActivityLog, proposed to retrieve employee activity records. 
The procedure must accommodate optional filtering parameters, specifically: Employee ID, a defined date range, 
and a maximum row limit for the result set.

### Purpose
This procedure is designed to provide a flexible way to audit employee actions. 
It allows administrators to track what an employee has done, when they did it, 
and from which IP address, with the ability to limit results for performance.
*/

USE [DCN-Miju];
GO

CREATE OR ALTER PROCEDURE usp_GetEmployeeActivityLog
    @EmployeeID BIGINT = NULL,
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL,
    @MaxRows INT = 100
AS
BEGIN
    SELECT TOP (@MaxRows) 
        al.Id, al.ActivityType, al.Description, al.UpdatedOn, al.IP,
        e.FirstName, e.LastName
    FROM Main.ActivityLog al
    LEFT JOIN Main.Employee e ON al.UpdatedBy = e.Id
    WHERE (@EmployeeID IS NULL OR al.UpdatedBy = @EmployeeID)
      AND (@StartDate IS NULL OR al.UpdatedOn >= @StartDate)
      AND (@EndDate IS NULL OR al.UpdatedOn <= @EndDate)
    ORDER BY al.UpdatedOn DESC;
END;
GO

/*
### Execution (EXEC)
Example 1: Retrieve the latest 50 activities for all employees
Example 2: Retrieve activities for a specific employee (ID: 1)
Example 3: Retrieve activities within a specific date range with a limit of 10 rows
*/

EXEC usp_GetEmployeeActivityLog @MaxRows = 50;
EXEC usp_GetEmployeeActivityLog @EmployeeID = 1;
EXEC usp_GetEmployeeActivityLog @StartDate = '2024-05-01', @EndDate = '2024-05-10', @MaxRows = 10;

/*
### Execution Explanation
1. Example 1: Fetches a general overview of recent actions across the entire system.
2. Example 2: Filters the log to show only the actions performed by the employee with ID 1.
3. Example 3: Investigates activities during a specific window of time.

-------------------------------------------------------------------------------

## Question 2
Write a stored procedure named usp_GetEmployeeSummary that furnishes employee statistical data, 
including the total number of employees, active employees, and archived employees, 
with optional filtering capability by account.

### Purpose
The purpose of this procedure is to give a high-level overview of the workforce status. 
It helps in understanding the distribution between active and inactive (archived) staff.
*/

GO

CREATE OR ALTER PROCEDURE usp_GetEmployeeSummary
    @AccountId BIGINT = NULL
AS
BEGIN
    SELECT 
        COUNT(*) AS TotalEmployees,
        SUM(CASE WHEN Archived = 0 THEN 1 ELSE 0 END) AS ActiveEmployees,
        SUM(CASE WHEN Archived = 1 THEN 1 ELSE 0 END) AS ArchivedEmployees
    FROM Main.Employee
    WHERE (@AccountId IS NULL OR AccountId = @AccountId);
END;
GO

/*
### Execution (EXEC)
Example 1: Get summary for the entire organization
Example 2: Get summary for Account ID 1
Example 3: Get summary for Account ID 2
*/

EXEC usp_GetEmployeeSummary;
EXEC usp_GetEmployeeSummary @AccountId = 1;
EXEC usp_GetEmployeeSummary @AccountId = 2;

/*
### Execution Explanation
1. Example 1: Provides a global count of all employees.
2. Example 2: Limits the statistical data to only those employees assigned to Account 1.
3. Example 3: Facilitates a direct comparison of employee distribution between different accounts.

-------------------------------------------------------------------------------

## Question 3
Write a stored procedure named usp_GetActivityReport that generates a report detailing activity 
counts stratified by type and action within a specified date range, with aggregation 
performed by activity type.

### Purpose
This procedure generates an analytical report to see which types of activities are most common. 
Stratifying by "Action" provides deeper insight into the specific operations performed.
*/

GO

CREATE OR ALTER PROCEDURE usp_GetActivityReport
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SELECT 
        ActivityType,
        [Action],
        COUNT(*) AS ActivityCount
    FROM Main.ActivityLog
    WHERE UpdatedOn >= @StartDate AND UpdatedOn <= @EndDate
    GROUP BY ActivityType, [Action]
    ORDER BY ActivityType, [Action];
END;
GO

/*
### Execution (EXEC)
Example 1: Report for the current month (May 2024)
Example 2: Report for a specific single day
Example 3: Long-term historical report (Year 2023)
*/

EXEC usp_GetActivityReport @StartDate = '2024-05-01', @EndDate = '2024-05-31';
EXEC usp_GetActivityReport @StartDate = '2024-05-10', @EndDate = '2024-05-10 23:59:59';
EXEC usp_GetActivityReport @StartDate = '2023-01-01', @EndDate = '2023-12-31';

/*
### Execution Explanation
1. Example 1: Provides a high-level view of system usage patterns for a month.
2. Example 2: Zooms in on a single day's activities.
3. Example 3: Helps stakeholders identify seasonal trends.

-------------------------------------------------------------------------------

## Question 4
Write a stored procedure named usp_SearchContacts designed to facilitate the search for contacts 
based on name or email address, incorporating support for pagination. 
The procedure should return both the search results and the total count of matching records.

### Purpose
To provide an efficient search mechanism for the contact list. Pagination ensures 
the application remains responsive even with large datasets.
*/

GO

CREATE OR ALTER PROCEDURE usp_SearchContacts
    @SearchTerm NVARCHAR(100) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10
AS
BEGIN
    SELECT Id, Name, Email, Archived
    FROM Main.Contact
    WHERE (@SearchTerm IS NULL OR Name LIKE '%' + @SearchTerm + '%' OR Email LIKE '%' + @SearchTerm + '%')
    ORDER BY Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    SELECT COUNT(*) AS TotalCount
    FROM Main.Contact
    WHERE (@SearchTerm IS NULL OR Name LIKE '%' + @SearchTerm + '%' OR Email LIKE '%' + @SearchTerm + '%');
END;
GO

/*
### Execution (EXEC)
Example 1: Search for 'ibrahim' on page 1
Example 2: Search for 'john' on page 1
Example 3: View page 2 of results containing 'test'
*/

EXEC usp_SearchContacts @SearchTerm = 'ibrahim', @PageNumber = 1, @PageSize = 10;
EXEC usp_SearchContacts @SearchTerm = 'john', @PageNumber = 1, @PageSize = 10;
EXEC usp_SearchContacts @SearchTerm = 'test', @PageNumber = 2, @PageSize = 5;

/*
### Execution Explanation
1. Example 1: Searches for contacts containing 'ibrahim' (first 10 matches).
2. Example 2: Demonstrates the flexibility of the keyword search for 'john'.
3. Example 3: Essential for handling large contact lists in a UI.

-------------------------------------------------------------------------------

## Question 5
Write a stored procedure named usp_GetWorkflowParticipants that retrieves the participants 
associated with a given workflow, including their corresponding employee details, 
and orders the output according to the participant order.

### Purpose
This procedure identifies who is involved in a specific business process (Workflow).
*/

GO

CREATE OR ALTER PROCEDURE usp_GetWorkflowParticipants
    @WorkflowId BIGINT
AS
BEGIN
    SELECT 
        p.[Order],
        p.Name AS ParticipantName,
        e.FirstName,
        e.LastName,
        e.Email
    FROM Workflow.Participant p
    LEFT JOIN Main.Employee e ON p.UserId = e.Id
    WHERE p.WorkflowId = @WorkflowId
    ORDER BY p.[Order];
END;
GO

/*
### Execution (EXEC)
Example 1: Get participants for Workflow ID 1
Example 2: Get participants for Workflow ID 2
Example 3: Get participants for Workflow ID 10
*/

EXEC usp_GetWorkflowParticipants @WorkflowId = 1;
EXEC usp_GetWorkflowParticipants @WorkflowId = 2;
EXEC usp_GetWorkflowParticipants @WorkflowId = 10;

/*
### Execution Explanation
1. Example 1: Shows employees assigned to the first workflow.
2. Example 2: Provides participant details for another workflow.
3. Example 3: Demonstrates sorting by the Order column.

-------------------------------------------------------------------------------

## Question 6
Write a stored procedure named usp_GetEmployeeLoginHistory that returns the most recent 
login dates for employees, offering options to filter the results by a date range and 
to restrict the output to only those employees who have not logged in recently.

### Purpose
To monitor user engagement and security by identifying stale accounts.
*/

GO

CREATE OR ALTER PROCEDURE usp_GetEmployeeLoginHistory
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL,
    @NotLoggedInRecently BIT = 0
AS
BEGIN
    SELECT 
        e.Id,
        e.FirstName,
        e.LastName,
        MAX(lh.[Date]) AS LastLoginDate
    FROM Main.Employee e
    LEFT JOIN Main.LoginHistory lh ON e.Id = lh.UserId
    WHERE (@StartDate IS NULL OR lh.[Date] >= @StartDate)
      AND (@EndDate IS NULL OR lh.[Date] <= @EndDate)
    GROUP BY e.Id, e.FirstName, e.LastName
    HAVING (@NotLoggedInRecently = 0 
            OR MAX(lh.[Date]) < DATEADD(day, -30, GETDATE()) 
            OR MAX(lh.[Date]) IS NULL)
    ORDER BY LastLoginDate DESC;
END;
GO

/*
### Execution (EXEC)
Example 1: View login history for all employees
Example 2: Identify inactive employees (no login in last 30 days)
Example 3: View logins between specific dates
*/

EXEC usp_GetEmployeeLoginHistory;
EXEC usp_GetEmployeeLoginHistory @NotLoggedInRecently = 1;
EXEC usp_GetEmployeeLoginHistory @StartDate = '2024-05-01', @EndDate = '2024-05-15';

/*
### Execution Explanation
1. Example 1: Snapshot of current system engagement.
2. Example 2: Specifically filters for inactive users.
3. Example 3: Verifying logins during a specific period.

-------------------------------------------------------------------------------

## Question 7
Write a stored procedure named usp_GenerateActivityDashboard that compiles a 
comprehensive dashboard showcasing activity metrics per employee, encompassing 
activity counts, the timestamp of the last activity, and the distribution of activity types.

### Purpose
To provide a 360-degree view of employee performance and resource allocation.
*/

GO

CREATE OR ALTER PROCEDURE usp_GenerateActivityDashboard
AS
BEGIN
    SELECT 
        e.Id,
        e.FirstName,
        e.LastName,
        ISNULL(Metrics.TotalActivities, 0) AS TotalActivities,
        Metrics.LastActivityTimestamp,
        Dist.ActivityDistribution
    FROM Main.Employee e
    OUTER APPLY (
        SELECT 
            COUNT(*) AS TotalActivities,
            MAX(UpdatedOn) AS LastActivityTimestamp
        FROM Main.ActivityLog
        WHERE UpdatedBy = e.Id
    ) Metrics
    OUTER APPLY (
        SELECT STRING_AGG(ActivitySummary, ', ') AS ActivityDistribution
        FROM (
            SELECT CAST(ActivityType AS VARCHAR) + ':' + CAST(COUNT(*) AS VARCHAR) AS ActivitySummary
            FROM Main.ActivityLog
            WHERE UpdatedBy = e.Id
            GROUP BY ActivityType
        ) t
    ) Dist
    ORDER BY TotalActivities DESC;
END;
GO

/*
### Execution (EXEC)
Example : Standard Dashboard execution
*/

EXEC usp_GenerateActivityDashboard;

/*
### Execution Explanation
1. Example : Highlights the most active users and their task distribution.
*/
