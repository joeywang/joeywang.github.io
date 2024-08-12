---
layout: post
title: Register Function
date: 2006-01-02 00:00 +0000
---
# Function Definition

## Register Information
This function allows the organization to specify what information is necessary for users to provide during the free trial registration. The organization can also choose which information should be visible to the first-time viewer through an interface.

1. **What the Organization Needs to Know**: Determine the free trial information required from the user.
2. **Interface for Information Visibility**: Provide an interface for the organization to decide which information should be presented to the first viewer.

## Course Assignment
The organization has the ability to assign a specific course to the user upon registration.

1. **Course ID Assignment**: The organization decides which course should be assigned to the registrant.

## Free Period
This function defines the duration of the free trial period for the registered user.

a. **From Registration to End Date**: The period starts from the day of registration to a specified end date.
b. **Set Amount of Days**: The organization can set a fixed number of days for the trial period starting from the registration day.

## Interface Definition

### Organization Admin Page
Functions related to registration need to be accessible from the organization's admin page.

a. **Checkbox for Registration Page**: To indicate if the organization has an active registration page.
b. **Button to Modify Settings**: Allows the organization to make changes to the registration settings.

### Register Setting Update Page
This page contains various elements for the organization to configure the registration process.

a. **Drop-down List Box**: For selecting the course ID to be assigned to the registrant.
b. **Group of Checkboxes**: To select which information is required for registration.
c. **Date Selection or Input Box**: For setting the duration of the free trial period.
d. **Delete Checkbox Option**: Allows removing specific options.
e. **Save Button**: To save the updated registration settings.

### Free Trial Register Management
This feature helps manage users who have registered for a free trial.

a. **User Type Addition**: Add a user type to identify free trial registrants.

## Database
A new table is required to store information about the registration page, and a new user type "RU" for Registered Users should be added.

- **New Table for Registration Info**: To store details about the registration page.
- **New User Type 'RU'**: To differentiate registered users.
