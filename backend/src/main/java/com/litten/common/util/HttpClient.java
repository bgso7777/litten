package com.litten.common.util;

import java.io.*;
import java.net.*;
import java.security.*;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Iterator;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

import com.litten.Constants;
import org.apache.http.client.ClientProtocolException;

public class HttpClient {

	public static final String SERVER_IP = "127.0.0.1";
	public static final String SERVER_POINT = "http://"+SERVER_IP+"/json.cmd";
	private String requestData = "";

	public HttpClient() {
	}

	public String requestHttpPost(String strUrl, String sendData) throws IOException {
		StringBuilder response = new StringBuilder();
		URL url = new URL (strUrl);
		HttpURLConnection httpURLConnection = (HttpURLConnection)url.openConnection();
		httpURLConnection.setRequestMethod("POST");
		httpURLConnection.setRequestProperty("Content-Type", "application/json; utf-8");
		httpURLConnection.setRequestProperty("Accept", "application/json");
		httpURLConnection.setDoOutput(true);

		OutputStream os = httpURLConnection.getOutputStream();
		byte[] input = sendData.getBytes("utf-8");
		os.write(input, 0, input.length);
		
		BufferedReader br = new BufferedReader(new InputStreamReader(httpURLConnection.getInputStream(), "utf-8"));
		String responseLine = null;
		while ((responseLine = br.readLine()) != null)
			response.append(responseLine.trim());

		return response.toString();
	}

	public String sendHttpDeleteByJSON(String strUrl, String data, HashMap<String,String> header) throws IOException {

		HttpURLConnection httpURLConnection = null;
		String result = null;

		URL url = new URL(strUrl);
		httpURLConnection = (HttpURLConnection) url.openConnection();

		httpURLConnection.setDoOutput(true);
		if(header!=null) {
			Iterator<String> keys = header.keySet().iterator();
			while( keys.hasNext() ) {
				String key = keys.next();
				String value = header.get(key);
				httpURLConnection.setRequestProperty(key, value);
			}
		}
		httpURLConnection.setRequestMethod("DELETE");

		if( data != null && !data.equals("") ){
			httpURLConnection.setDoInput(true);
			httpURLConnection.setDoOutput(true);
			DataOutputStream out = new  DataOutputStream(httpURLConnection.getOutputStream());
			out.writeBytes(data);
			out.flush();
			out.close();
		}
		httpURLConnection.connect();
		BufferedReader in = new BufferedReader(new InputStreamReader(httpURLConnection.getInputStream()));
		String temp = null;
		StringBuilder sb = new StringBuilder();
		while((temp = in.readLine()) != null) {
			sb.append(temp).append("\n");
		}
		result = sb.toString();
		in.close();

		if(httpURLConnection!=null)
			httpURLConnection.disconnect();
		return result;
	}

	public String sendHttpByJSON(String method, String strUrl, String data, HashMap<String,String> header) throws IOException {

		HttpURLConnection httpURLConnection = null;
		String result = null;

		URL url = new URL(strUrl);
		httpURLConnection = (HttpURLConnection) url.openConnection();

		httpURLConnection.setDoOutput(true);
		if(header!=null) {
			Iterator<String> keys = header.keySet().iterator();
			while( keys.hasNext() ) {
				String key = keys.next();
				String value = header.get(key);
				httpURLConnection.setRequestProperty(key, value);
			}
		}
		httpURLConnection.setRequestMethod(method);

		if( data != null && !data.equals("") ){
			httpURLConnection.setDoInput(true);
			httpURLConnection.setDoOutput(true);
			DataOutputStream out = new  DataOutputStream(httpURLConnection.getOutputStream());
			out.writeBytes(data);
			out.flush();
			out.close();
		}
		httpURLConnection.connect();
		BufferedReader in = new BufferedReader(new InputStreamReader(httpURLConnection.getInputStream()));
		String temp = null;
		StringBuilder sb = new StringBuilder();
		while((temp = in.readLine()) != null) {
			sb.append(temp).append("\n");
		}
		result = sb.toString();
		in.close();

		if(httpURLConnection!=null)
			httpURLConnection.disconnect();
		return result;
	}

	/**
	 *
	 * @param urlString
	 * @param data
	 * @param timeOut
	 * @param contentType
	 * @return
	 * @throws IOException
	 * @throws NoSuchAlgorithmException
	 * @throws KeyManagementException
	 */
	public String sendRequestByJSON2(String urlString, String data, long timeOut, String contentType, String method) throws IOException, NoSuchAlgorithmException, KeyManagementException {
		String resData = "";
		if(urlString.indexOf("https://")!=-1) {
			resData = sendRequestHttpsByJSON(urlString, data, timeOut, contentType, method);
		} else {
			resData = sendRequestHttpByJSON(urlString, data, timeOut, contentType, method);
		}
		return resData;
	}

	/**
	 *
	 * @param urlString
	 * @param data
	 * @param timeOut
	 * @param contentType
	 * @return
	 * @throws IOException
	 * @throws NoSuchAlgorithmException
	 * @throws KeyManagementException
	 */
	public String sendRequestByJSON2(String urlString, String data, long timeOut, String contentType) throws IOException, NoSuchAlgorithmException, KeyManagementException {
		String resData = "";
		if(urlString.indexOf("https://")!=-1) {
			resData = sendRequestHttpsByJSON(urlString, data, timeOut, contentType, "POST");
		} else {
			resData = sendRequestHttpByJSON(urlString, data, timeOut, contentType, "POST");
		}
		return resData;
	}

	public String sendRequestHttpsByJSON(String urlString, String data, long timeOut, String contentType, String method) throws IOException, NoSuchAlgorithmException, KeyManagementException {
			
		StringBuffer resData = new StringBuffer();
		
		// Get HTTPS URL connection
		URL url = new URL(urlString);
		HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
		conn.setDoInput(true);
		conn.setDoOutput(true);
//		conn.setRequestMethod("POST");
		conn.setRequestMethod(method);
		conn.setFollowRedirects(true); 
		conn.setRequestProperty("Content-length",String.valueOf (data.length())); 
		if(contentType.equals(""))
			conn.setRequestProperty("Content-Type","application/x-www- form-urlencoded");
		else
			conn.setRequestProperty("Content-Type",contentType);
//		conn.setRequestProperty("User-Agent", "Mozilla/4.0 (compatible; MSIE 5.0; Windows 98; DigExt)");
		conn.setRequestProperty("Content-Language", "UTF-8");
		if(timeOut>0)
			conn.setConnectTimeout(3000);
		
		// Set Hostname verification
		conn.setHostnameVerifier(new HostnameVerifier() {
			public boolean verify(String hostname, SSLSession session) {
				// Ignore host name verification. It always returns true.
				return true;
			}
		});
		
		// SSL setting
		SSLContext context = SSLContext.getInstance("TLS");
		context.init(null, new TrustManager[] { new X509TrustManager() {
			@Override
			public void checkClientTrusted(X509Certificate[] chain,
					String authType) throws CertificateException {
				// client certification check
			}
			@Override
			public void checkServerTrusted(X509Certificate[] chain,	String authType) throws CertificateException {
				// Server certification check
				try {
					// Get trust store
					KeyStore trustStore = KeyStore.getInstance("JKS");
					//if(System.getProperty("os.name").toLowerCase().indexOf("win")!=-1) {
					//if(Environment.getInstance().getRunMode1().equals(Environment.ITCMS_SERVICE_MODE)) {
						trustStore.load(new FileInputStream("truststore.jks"),"changeit".toCharArray());
					//} else {
					//	String cacertPath = System.getProperty("java.home") + "/lib/security/cacerts"; // Trust store path should be different by system platform.  
					//	trustStore.load(new FileInputStream(cacertPath), "changeit".toCharArray()); // Use default certification validation
					//}

					// Get Trust Manager
					TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
					tmf.init(trustStore);
					TrustManager[] tms = tmf.getTrustManagers();
					((X509TrustManager) tms[0]).checkServerTrusted(chain, authType);
					
				} catch (KeyStoreException e) {
					e.printStackTrace();
				} catch (NoSuchAlgorithmException e) {
					e.printStackTrace();
				} catch (IOException e) {
					e.printStackTrace();
				}
			}
			@Override
			public X509Certificate[] getAcceptedIssuers() {
				return null;
			}
		} }, null);
		conn.setSSLSocketFactory(context.getSocketFactory());

		// Connect to host
		conn.connect();
		conn.setInstanceFollowRedirects(true);
		
		// open up the output stream of the connection 
		DataOutputStream output = new DataOutputStream( conn.getOutputStream() );
		
		// write out the data 
		//int queryLength = data.length(); 
		output.writeBytes(data.toString()); 
		
		// Print response from host
		InputStream in = conn.getInputStream();
		BufferedReader reader = new BufferedReader(new InputStreamReader(in,"UTF-8"));
		String line = null;
		while ((line = reader.readLine()) != null)
			resData.append(line+"\n");
		reader.close();
		return resData.toString();
	}

	public String excuteGet(String stringUrl, String charSet) throws IOException {

		StringBuffer response = new StringBuffer();
		HttpURLConnection connection = null;

		// Create connection
		URL url = new URL(stringUrl);
		connection = (HttpURLConnection) url.openConnection();
		connection.setRequestMethod("GET");
		if(!charSet.equals(""))
			connection.setRequestProperty("Content-Language",charSet);
		connection.setUseCaches(false);
		connection.setDoInput(true);
		connection.setDoOutput(true);

		// Get Response
		InputStream is = connection.getInputStream();
		InputStreamReader inputStreamReader = new InputStreamReader(is,charSet);
		BufferedReader rd = new BufferedReader(inputStreamReader);
		String line;

		while ((line = rd.readLine()) != null) {
			response.append(line);
			response.append('\r');
		}
		rd.close();

		return response.toString();
	}

	public String getRequestData() {
		return requestData;
	}

	public String sendRequestHttpByJSON(String urlString, String data, long timeOut, String contentType, String method) throws ClientProtocolException, IOException {
		URL url = new URL(urlString);
		HttpURLConnection connection = (HttpURLConnection) url.openConnection();
//		connection.setRequestMethod("POST");
		connection.setRequestMethod(method);
		connection.setRequestProperty("Content-Type", "application/json");
		//connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
		connection.setRequestProperty("Content-Length",	"" + Integer.toString(data.getBytes().length));
		connection.setRequestProperty("Content-Language", "UTF-8");
		connection.setUseCaches(false);
		connection.setDoInput(true);
		connection.setDoOutput(true);

		// Send request
		DataOutputStream wr = new DataOutputStream(connection.getOutputStream());
		wr.writeBytes(data);
		wr.flush();
		wr.close();

		// Get Response
		InputStream is = connection.getInputStream();
		InputStreamReader inputStreamReader = new InputStreamReader(is);
		//System.out.println( inputStreamReader.getEncoding() );
		BufferedReader rd = new BufferedReader(inputStreamReader);
		String line;
		StringBuffer response = new StringBuffer();
		while ((line = rd.readLine()) != null) {
			response.append(line);
			response.append('\r');
		}
		rd.close();
		return response.toString();
	}

	/**
	 * 
	 * @param args
	 * @throws Exception
	 */ 
	public static void main_(String[] args) throws Exception {
		System.out.println("===========================");
		HttpClient test = new HttpClient();
//		String url = "http://10.0.131.55:8787/aice/billing";
		String url = "https://dev-backdoor.ploonet.com/billing";

		StringBuffer sndData = new StringBuffer("");

		sndData.append("        { ");
		sndData.append("            \"solutionType\":\"B13\"");
		sndData.append("                ,\"fkCompany\":-1");
		sndData.append("                ,\"items\":[{");
		sndData.append("                    \"itemCd\":\"CARD_SM_001\"");
		sndData.append("                    ,\"itemType\":\"SUBSC_MAIN\"");
		sndData.append("                    ,\"itemStatus\":\"B20102\"");
		sndData.append("                    ,\"payDtFrom\":\""+DateUtil.getCurrentDate(Constants.TAG_DATE_PATTERN_OF_ADMIN_DISPLAY)+"\"");
		sndData.append("                }]");
		sndData.append("        }");

		System.out.println(sndData.toString());
		System.out.println("===========================");
		String rcvData = test.sendRequestByJSON2(url,sndData.toString(),3000,"utf-8");
		System.out.println(rcvData.toString());
		System.out.println("===========================");
	}

	public static void main(String[] args) throws Exception {


		class T1 extends Thread {
			public void run() {
				for (int i = 0; i < 5; i++) {
					try {
						HttpClient httpClient1 = new HttpClient();
						StringBuffer sndData1 = new StringBuffer("");
						sndData1.append("{\"signUpPathCode\":\"A3022\",\"name\":\"이승구"+i+"\",\"email\":\"well1225@naver.com"+i+"\",\"mobile\":\"01053609113\",\"password\":\"wkwk1225*\"}");

						System.out.println(LocalDateTime.now().toString() +" [t1] "+ sndData1.toString());
						System.out.println(LocalDateTime.now().toString() +" [t1] "+ httpClient1.requestHttpPost("http://localhost:8989/account/anon/member", sndData1.toString()));

					} catch(Exception e) {
						e.printStackTrace();
					}
				}
			}
		};
		T1 t1 = new T1();

		class T2 extends Thread {
			public void run() {
				for (int i = 0; i < 5; i++) {
					try {
						HttpClient httpClient2 = new HttpClient();
						StringBuffer sndData2 = new StringBuffer("");
						sndData2.append("{\"signUpPathCode\":\"A3022\",\"name\":\"이두식"+i+"\",\"email\":\"seagee@naer.com"+i+"\",\"mobile\":\"01042053115\",\"password\":\"dslee1pl!@\"}");

						System.out.println(LocalDateTime.now().toString() + " [t2] " + sndData2.toString());
						System.out.println(LocalDateTime.now().toString() + " [t2] " + httpClient2.requestHttpPost("http://localhost:8989/account/anon/member", sndData2.toString()));

					} catch (Exception e) {
						e.printStackTrace();
					}
				}
			}
		};
		T2 t2 = new T2();

		t1.start();
		t2.start();

	}


}
