--
-- create sample database
--

USE [master]

CREATE DATABASE Sales

GO

USE [Sales]

CREATE TABLE CUSTOMER (
  [CustomerID] [int] PRIMARY KEY,
  [SalesAmount] [decimal] NOT NULL,
  [Name] VARCHAR(255)
)

INSERT INTO CUSTOMER (CustomerID, SalesAmount, Name)
VALUES
  (1, 100, "Andrea"),
  (2, 200, "Marco"),
  (3, 300, "Giovanni")

GO
