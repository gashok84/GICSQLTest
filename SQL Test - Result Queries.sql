
-- Create the Library database
CREATE DATABASE Library
ON
( NAME = 'Library_data',
  FILENAME = 'C:\data\Library_data.mdf', 
  SIZE = 10MB,
  MAXSIZE = UNLIMITED,
  FILEGROWTH = 5MB )
LOG ON
( NAME = 'Library_log',
  FILENAME = 'C:\data\Library_log.ldf', 
  SIZE = 5MB,
  MAXSIZE = 50MB,
  FILEGROWTH = 5MB );


  --use Library
USE Library;

-- books table
CREATE TABLE Books (
    book_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    title NVARCHAR(255) NOT NULL,
    author NVARCHAR(255) NOT NULL,
    publication_year INT,
    isbn NVARCHAR(20) UNIQUE,
    created_date DATETIME DEFAULT GETDATE(),
    INDEX IX_books_isbn (isbn)
);

-- users table
CREATE TABLE Users (
    user_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) UNIQUE,
    registration_date DATETIME DEFAULT GETDATE()
);

-- borrowed_books table
CREATE TABLE Borrowed_books (
    borrow_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    user_id UNIQUEIDENTIFIER,
    book_id UNIQUEIDENTIFIER,
    borrow_date DATETIME,
    return_date DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id)
);





/* 1. Write a SQL query to retrieve the top 10 most borrowed books, 
	  along with the number of times each book has been borrowed */

	WITH BorrowedBooks AS (
		SELECT
			b.title AS book_title,
			COUNT(bb.borrow_id) AS borrow_count,
			RANK() OVER (ORDER BY COUNT(bb.borrow_id) DESC) AS ranking
		FROM
			borrowed_books bb
		JOIN
			books b ON bb.book_id = b.book_id
		GROUP BY
			b.title
	)

	SELECT
		book_title,
		borrow_count
	FROM
		BorrowedBooks
	WHERE
		ranking <= 10
	ORDER BY
		ranking;



/* 2. Create a stored procedure that calculates the average number of days a book is borrowed before being returned. 
	The procedure should take a book_id as input and return the average number of days. */

		IF OBJECT_ID('CalAverageBorrowDuration', 'P') IS NOT NULL
			DROP PROCEDURE CalAverageBorrowDuration;
		GO

		--Create SP
		CREATE PROCEDURE CalAverageBorrowDuration
			@input_book_id UNIQUEIDENTIFIER
		AS
		BEGIN
			SET NOCOUNT ON;

			DECLARE @average_duration FLOAT;

			-- Calculate average duration
			SELECT @average_duration = AVG(DATEDIFF(DAY, borrow_date, ISNULL(return_date, GETDATE())))
			FROM borrowed_books
			WHERE book_id = @input_book_id;

			-- Return the result
			SELECT @average_duration AS average_borrow_duration;
		END;

/* 3. Write a query to find the user who has borrowed the most books from the library. */

		SELECT TOP 1
			u.user_id,
			u.first_name,
			u.last_name,
			COUNT(bb.borrow_id) AS borrowed_books_count
		FROM
			users u
		JOIN
			borrowed_books bb ON u.user_id = bb.user_id
		GROUP BY
			u.user_id, u.first_name, u.last_name
		ORDER BY
			borrowed_books_count DESC;


 /* 4. Create an index on the publication_year column of the books table to improve query performance. */ 

		-- Drop the index if it exists
		IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_books_publication_year' AND object_id = OBJECT_ID('books'))
			DROP INDEX IX_books_publication_year ON books;
		GO

		-- Create the index
		CREATE INDEX IX_books_publication_year ON books (publication_year);



/* 5.  Write a SQL query to find all books published in the year 2020 that have not been borrowed by any user. */

		SELECT b.*
		FROM books b
		LEFT JOIN borrowed_books bb ON b.book_id = bb.book_id
		WHERE b.publication_year = 2020
			AND bb.book_id IS NULL;


/* 6. Design a SQL query that lists users who have borrowed books published by a specific author (e.g., "J.K. Rowling"). */

		SELECT DISTINCT u.*
		FROM users u
		JOIN borrowed_books bb ON u.user_id = bb.user_id
		JOIN books b ON bb.book_id = b.book_id
		WHERE b.author = 'George Orwell';


/* 7.  Create a trigger that automatically updates the return_date in the borrowed_books table to the current date when a book is returned. */ 

		-- Disable the trigger if it exists
		IF OBJECT_ID('TrUpdateReturnDate', 'TR') IS NOT NULL
			DISABLE TRIGGER TrUpdateReturnDate ON borrowed_books;
		GO

		-- Drop the trigger if it exists
		IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'TrUpdateReturnDate' AND parent_id = OBJECT_ID('borrowed_books'))
			DROP TRIGGER TrUpdateReturnDate;
		GO

		-- create trigger
		CREATE TRIGGER TrUpdateReturnDate
		ON borrowed_books
		AFTER UPDATE
		AS
		BEGIN
			IF UPDATE(return_date)  
			BEGIN
				UPDATE borrowed_books
				SET return_date = GETDATE()
				FROM inserted
				WHERE borrowed_books.borrow_id = inserted.borrow_id
					AND inserted.return_date IS NOT NULL;
			END
		END;

