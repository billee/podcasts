# Kapwa Companion - System Architecture Diagrams

## 1. High-Level System Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        A[Flutter Mobile App]
        B[Admin Dashboard Web]
    end
    
    subgraph "Backend Services"
        C[Python Flask API<br/>Render.com]
        D[OpenAI API<br/>GPT Integration]
    end
    
    subgraph "Database Layer"
        E[Firebase Firestore<br/>User Data & Subscriptions]
        F[Firebase Auth<br/>Authentication]
    end
    
    subgraph "Payment Processing"
        G[Mock Payment System<br/>Stripe Integration Ready]
    end
    
    A --> C
    B --> C
    C --> D
    C --> E
    C --> F
    A --> E
    A --> F
    A --> G
    
    style A fill:#e1f5fe
    style B fill:#e8f5e8
    style C fill:#fff3e0
    style D fill:#fce4ec
    style E fill:#f3e5f5
    style F fill:#f3e5f5
    style G fill:#e0f2f1
```

## 2. Flutter App Architecture

```mermaid
graph TB
    subgraph "Presentation Layer"
        A[Screens]
        B[Widgets]
        C[Views]
    end
    
    subgraph "Business Logic Layer"
        D[Services]
        E[Models]
        F[Utils]
    end
    
    subgraph "Data Layer"
        G[Firebase Firestore]
        H[Local Storage]
        I[HTTP Client]
    end
    
    subgraph "Core"
        J[Config]
        K[Token Counter]
        L[App State]
    end
    
    A --> D
    B --> D
    C --> D
    D --> G
    D --> H
    D --> I
    D --> J
    D --> K
    E --> G
    F --> J
    
    style A fill:#e3f2fd
    style D fill:#fff8e1
    style G fill:#f1f8e9
    style J fill:#fce4ec
```

## 3. Token Management System

```mermaid
graph TB
    subgraph "User Interaction"
        A[User Sends Message]
        B[Chat Screen]
    end
    
    subgraph "Token Processing"
        C[Token Counter Service]
        D[Token Limit Service]
        E[System Prompt Service]
    end
    
    subgraph "LLM Integration"
        F[Flask Backend API]
        G[OpenAI GPT API]
    end
    
    subgraph "Storage & Tracking"
        H[Daily Token Usage<br/>Firestore Collection]
        I[Historical Usage<br/>Monthly Aggregation]
        J[User Limits<br/>Trial: 10k, Premium: 100k]
    end
    
    subgraph "Reset System"
        K[Date Override Config<br/>Testing Support]
        L[Automatic Daily Reset<br/>24:00 Midnight]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> F
    F --> C
    C --> H
    H --> I
    D --> J
    K --> L
    L --> D
    
    style A fill:#e8f5e8
    style C fill:#fff3e0
    style F fill:#fce4ec
    style H fill:#f3e5f5
    style K fill:#ffebee
```

## 4. Subscription Management Flow

```mermaid
graph TB
    subgraph "User States"
        A[New User<br/>7-Day Trial]
        B[Trial Active<br/>10k Daily Tokens]
        C[Trial Expired<br/>Limited Access]
        D[Premium Subscriber<br/>100k Daily Tokens]
        E[Cancelled<br/>Access Until Period End]
    end
    
    subgraph "Payment Flow"
        F[Subscription Screen]
        G[Mock Payment Screen<br/>$3/month]
        H[Payment Processing]
        I[Subscription Activation]
    end
    
    subgraph "Data Storage"
        J[Trial History<br/>Firestore Collection]
        K[Subscriptions<br/>Firestore Collection]
        L[User Status<br/>Real-time Updates]
    end
    
    A --> B
    B --> C
    B --> F
    C --> F
    F --> G
    G --> H
    H --> I
    I --> D
    D --> E
    
    B --> J
    D --> K
    E --> K
    J --> L
    K --> L
    
    style A fill:#e8f5e8
    style B fill:#e3f2fd
    style C fill:#ffebee
    style D fill:#e0f2f1
    style F fill:#fff3e0
    style J fill:#f3e5f5
```

## 5. Conversation Management System

```mermaid
graph TB
    subgraph "Chat Flow"
        A[User Message Input]
        B[Message Validation]
        C[Token Pre-Check]
        D[LLM Processing]
        E[Response Generation]
        F[Violation Detection]
    end
    
    subgraph "Conversation State"
        G[Message History<br/>Local Storage]
        H[Conversation Pairs<br/>Counter]
        I[Summarization Trigger<br/>Every 6 Pairs]
        J[Message Limiting<br/>Last 10 Messages]
    end
    
    subgraph "Optimization"
        K[System Prompt<br/>Optimized 315 tokens]
        L[Ultra-Concise Summaries<br/>1-2 sentences]
        M[Aggressive Summarization<br/>40% more frequent]
    end
    
    subgraph "Storage"
        N[Conversation Summaries<br/>Firestore]
        O[Violation Logs<br/>Firestore]
        P[App State Persistence<br/>SharedPreferences]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    I --> J
    J --> K
    K --> L
    L --> M
    
    G --> N
    F --> O
    G --> P
    
    style A fill:#e8f5e8
    style D fill:#fce4ec
    style I fill:#fff3e0
    style K fill:#e0f2f1
    style N fill:#f3e5f5
```

## 6. Data Flow Architecture

```mermaid
sequenceDiagram
    participant U as User
    participant A as Flutter App
    participant T as Token Service
    participant B as Flask Backend
    participant O as OpenAI API
    participant F as Firestore
    
    U->>A: Send Chat Message
    A->>T: Check Token Limit
    T->>F: Get Daily Usage
    F-->>T: Return Usage Data
    T-->>A: Limit Check Result
    
    alt Token Limit OK
        A->>B: Send Message + Context
        B->>O: LLM Request
        O-->>B: AI Response
        B-->>A: Formatted Response
        A->>T: Record Token Usage
        T->>F: Update Daily Usage
        A->>U: Display Response
    else Token Limit Exceeded
        A->>U: Show Limit Dialog
    end
```

## How to Use in Draw.io:

1. **Open Draw.io** (app.diagrams.net)
2. **Create New Diagram**
3. **Insert → Advanced → Mermaid**
4. **Copy and paste** any of the above Mermaid code blocks
5. **Click "Insert"** to generate the diagram
6. **Edit and customize** as needed

Each diagram focuses on a different aspect of your system:
- **Diagram 1**: Overall system architecture
- **Diagram 2**: Flutter app structure  
- **Diagram 3**: Token management system
- **Diagram 4**: Subscription flow
- **Diagram 5**: Conversation management
- **Diagram 6**: Data flow sequence

You can use these individually or combine them for comprehensive documentation!