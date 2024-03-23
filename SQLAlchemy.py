from sqlalchemy import create_engine, Column, Integer, Text, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session

connection = create_engine("mysql://<username>:<password>@localhost:3306/nemocnice")

Base = declarative_base()

class Visit(Base):
    __tablename__ = 'Visits'  
    Visit_ID = Column("Visit_ID", Integer, primary_key=True)  
    Date_of_visit = Column("Date_of_visit", Text)  
    Duration_of_visit = Column("Duration_of_visit", Integer)  

session = Session(connection)

def count(duration):
    count = session.query(func.count()).select_from(Visit).filter(Visit.Duration_of_visit >= duration).scalar()
    print(f"Number of visits lasting {duration} minutes or more: {count}")

duration = int(input("How many minutes?: "))
count(duration)

session.close()
