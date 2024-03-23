
#include <Arrays/Array.mqh>  


template <typename T> 
class CPool : public CArray {
   protected:
      T        m_data[]; 
   private:
   public:
      CPool() { ArrayResize(m_data, 0); }
      CPool(int size)   { ArrayResize(m_data, size); }
      ~CPool() { Clear(); } 
      
      int         Size()   { return ArraySize(m_data); } 
      
      T           Item(int index)      { return m_data[index]; }
      
      virtual     int         Create(T &elements[]); 
      virtual     void        Append(T &element); 
      virtual     bool        Search(T &element); 
      virtual     int         Extract(T &data[]); 
      virtual     string      ArrayAsString(); 
                  void        Clear(); 
                  int         Pop(int index); 
                  int         Dequeue(); 
};

template <typename T> 
void           CPool::Clear(void) {
   ArrayFree(m_data);
   ArrayResize(m_data, 0); 
   ZeroMemory(m_data); 
}

template <typename T> 
void           CPool::Append(T &element) {
   int size = Size(); 
   ArrayResize(m_data, size+1); 
   m_data[size]    = element; 
}


template <typename T>
int            CPool::Pop(int index) {
   T dummy[]; 
   
   int size = Size(); 
   for (int i = 0; i < size; i++) {
      if (i == index) continue; 
      
      int dummy_size = ArraySize(dummy);
      ArrayResize(dummy, dummy_size+1); 
      dummy[dummy_size] = m_data[i]; 
   }
   
   Clear(); 
   Create(dummy); 
   return Size(); 
}

template <typename T>
int         CPool::Create(T &elements[]) {
   int size = ArraySize(elements); 
   ArrayResize(m_data, size); 
   for (int i = 0; i < size; i++) m_data[i] = elements[i]; 
   return ArraySize(m_data); 
   
}

template <typename T> 
int         CPool::Dequeue(void)    { return Pop(0); }





template <typename T> 
class CPoolGeneric : public CPool<T> {
   private:
   protected:
   public: 
      CPoolGeneric(){};
      ~CPoolGeneric() {}; 
      
      virtual     bool     Search(T &element); 
      virtual     string   ArrayAsString(); 
      virtual     int      Create(T &elements[]);
      virtual     int      Extract(T &data[]); 
      virtual     int      Remove(T element); 
};

template <typename T> 
bool        CPoolGeneric::Search(T &element) {
   int size = Size(); 
   for (int i = 0; i < size; i++) if (element == m_data[i]) return true; 
   return false;
}

template <typename T> 
string         CPoolGeneric::ArrayAsString(void) {
   
   int size = Size();
   string array_string  = ""; 
   for (int i = 0; i < size; i++) {
      T item   = m_data[i]; 
      if (i == 0) array_string   = (string)item; 
      else array_string          = StringConcatenate(array_string, ",", (string)item); 
   }
   return array_string; 
}

template <typename T> 
int            CPoolGeneric::Create(T &elements[]) {
   int size = ArraySize(elements); 
   ArrayResize(m_data, size); 
   ArrayCopy(m_data, elements, 0, 0);
   return Size();
}

template <typename T> 
int            CPoolGeneric::Extract(T &data[]) {
   int size = Size(); 
   ArrayResize(data, size);
   ArrayCopy(data, m_data); 
   return ArraySize(data); 
}

template <typename T>
int            CPoolGeneric::Remove(T element) {
   /*
   int size = Size(); 
   
   CPoolGeneric<T> dummy = new CPoolGeneric<T>();
      
   for (int i = 0; i < size; i++) {
      T item = Item(i); 
      if (item == element) continue;
      dummy.Append(item);    
   }
   Clear(); 
   T extracted[];
   int num_extracted = Extract(extracted);
   Create(extracted); 
   return Size(); */ 
   return 0; 
}


template <typename T> 
class CPoolObject : public CPool<T> {
   public:
      CPoolObject() {};
      ~CPoolObject(){}; 
      
};

