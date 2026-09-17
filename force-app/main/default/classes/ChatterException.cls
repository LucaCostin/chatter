public class ChatterException extends Exception {
    public static ChatterException security(String msg)   { return new ChatterException(msg); }
    public static ChatterException validation(String msg) { return new ChatterException(msg); }
    public static ChatterException notFound(String msg)   { return new ChatterException(msg); }
    public static ChatterException unknown(String msg)    { return new ChatterException(msg); }
    public static ChatterException fromConnect(Exception cause) {
        String m = cause == null ? 'Unknown Connect error' : cause.getMessage();
        return new ChatterException(m);
    }
}