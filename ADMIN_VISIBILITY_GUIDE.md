# 🔍 Admin Access Visibility Guide

## 🎯 **Where to Find Admin Access (Testing Mode)**

### **1. 🔴 Floating Action Button (Most Visible)**
- **Location**: Bottom-right corner of the main screen
- **Appearance**: Red circular button with admin icon (⚙️👤)
- **Always Visible**: On all tabs (Chat, Podcast, Story, Profile)
- **Action**: Tap to open Admin Dashboard directly

### **2. 🔝 Main App Bar**
- **Location**: Top-right corner of main screen
- **Icon**: Admin panel settings icon (⚙️👤)
- **Position**: After "Upgrade" button, before "Sign Out"
- **May be hidden**: If app bar is crowded or screen is small

### **3. 👤 Profile Screen**
- **Location**: Profile tab → Scroll down to "Payment & Billing" section
- **Button**: Red "Admin Dashboard" button
- **Position**: Below "Manage Subscription" button
- **Debug Info**: Orange debug box shows admin status

## 🔧 **Debug Information**

When you go to the **Profile tab**, you should see an **orange debug box** at the top showing:
- **Admin User**: true/false
- **Debug Mode**: true/false  
- **User Type**: Current user type from database
- **Email**: Current user email

## 🚀 **Quick Test Steps**

1. **Open the app** and log in with any account
2. **Look for the red floating button** in the bottom-right corner
3. **Tap the floating button** → Should open Admin Dashboard
4. **In Admin Dashboard**, look for:
   - Green "Billing Administration" button
   - Payment icon (💳) in the app bar
   - User table with payment icons next to each user

## 🔍 **Troubleshooting**

### **If you don't see the floating button:**
1. Check that `_isDebugMode()` returns `true` in `main_screen.dart`
2. Make sure you're logged in (not on login screen)
3. Try switching between tabs to refresh the UI

### **If you don't see the admin button in profile:**
1. Go to Profile tab
2. Look for the orange debug box at the top
3. Check if "Debug Mode: true" and "Admin User: true/false"
4. Scroll down to find the red "Admin Dashboard" button

### **If admin dashboard is empty:**
1. The dashboard shows user journey data from Firestore
2. If no users exist, it will show empty tables
3. The billing features work independently of user data

## 🎯 **Expected Admin Dashboard Features**

Once you access the Admin Dashboard, you should see:

### **Main Dashboard**
- User statistics cards (Total Users, Active Trials, etc.)
- Green "Billing Administration" button
- User journey table

### **Billing Administration (5 tabs)**
- **Overview**: Metrics and quick actions
- **Payments**: Real-time payment monitoring  
- **Billing**: Recent billing activity
- **Refunds**: Pending refund requests
- **Failed**: Failed payments requiring attention

### **Per-User Billing**
- Payment icon (💳) next to each user in the table
- Click to see individual user's billing details

The admin access should be **highly visible** with the floating action button during testing! 🎯