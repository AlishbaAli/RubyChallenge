import React, { useState } from "react";
import {
  Upload,
  Users,
  Building2,
  CheckCircle,
  XCircle,
  Download,
  FileText,
  AlertCircle,
  Loader,
} from "lucide-react";
import "./App.css";

const API_URL = "http://localhost:4567/api";

function App() {
  const [usersFile, setUsersFile] = useState(null);
  const [companiesFile, setCompaniesFile] = useState(null);
  const [usersData, setUsersData] = useState(null);
  const [companiesData, setCompaniesData] = useState(null);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [outputText, setOutputText] = useState("");

  const handleFileUpload = (e, type) => {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const content = event.target.result;
        const jsonData = JSON.parse(content);

        if (type === "users") {
          setUsersFile(file.name);
          setUsersData(jsonData);
        } else {
          setCompaniesFile(file.name);
          setCompaniesData(jsonData);
        }
        setError(null);
      } catch (err) {
        setError(`Invalid JSON in ${type} file: ${err.message}`);
      }
    };
    reader.readAsText(file);
  };

  const processData = async () => {
    if (!usersData || !companiesData) {
      setError("Please upload both users and companies files");
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await fetch(`${API_URL}/process`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          users: usersData,
          companies: companiesData,
        }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        setResult(data.result);
        setOutputText(data.output);
      } else {
        setError(data.error || "Processing failed");
      }
    } catch (err) {
      setError(
        `Failed to connect to API server: ${err.message}. Make sure the server is running on http://localhost:4567`
      );
    } finally {
      setLoading(false);
    }
  };

  const downloadOutput = () => {
    const blob = new Blob([outputText], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "output.txt";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const resetApp = () => {
    setUsersFile(null);
    setCompaniesFile(null);
    setUsersData(null);
    setCompaniesData(null);
    setResult(null);
    setError(null);
    setOutputText("");
  };

  return (
    <div className="app">
      {/* Header */}
      <header className="header">
        <div className="header-content">
          <div className="header-icon">
            <FileText size={32} />
          </div>
          <div>
            <h1>Token Top-Up Processor</h1>
            <p>Process user token top-ups with company policies</p>
          </div>
        </div>
      </header>

      <div className="container">
        {/* Upload Section */}
        <div className="upload-section">
          {/* Users Upload */}
          <div className="upload-card">
            <div className="card-header">
              <Users size={24} />
              <h2>Upload Users</h2>
            </div>
            <label className={`upload-area ${usersFile ? "uploaded" : ""}`}>
              <input
                type="file"
                accept=".json"
                onChange={(e) => handleFileUpload(e, "users")}
                className="file-input"
              />
              <Upload size={48} className="upload-icon" />
              <p className="upload-text">
                {usersFile ? (
                  <>
                    <CheckCircle size={20} className="check-icon" />
                    {usersFile}
                  </>
                ) : (
                  <>
                    Click or drag to upload <strong>users.json</strong>
                  </>
                )}
              </p>
              <p className="upload-hint">JSON file with user data</p>
            </label>
          </div>

          {/* Companies Upload */}
          <div className="upload-card">
            <div className="card-header">
              <Building2 size={24} />
              <h2>Upload Companies</h2>
            </div>
            <label className={`upload-area ${companiesFile ? "uploaded" : ""}`}>
              <input
                type="file"
                accept=".json"
                onChange={(e) => handleFileUpload(e, "companies")}
                className="file-input"
              />
              <Upload size={48} className="upload-icon" />
              <p className="upload-text">
                {companiesFile ? (
                  <>
                    <CheckCircle size={20} className="check-icon" />
                    {companiesFile}
                  </>
                ) : (
                  <>
                    Click or drag to upload <strong>companies.json</strong>
                  </>
                )}
              </p>
              <p className="upload-hint">JSON file with company data</p>
            </label>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="action-buttons">
          <button
            onClick={processData}
            disabled={!usersData || !companiesData || loading}
            className="btn btn-primary"
          >
            {loading ? (
              <>
                <Loader className="spin" size={20} />
                Processing...
              </>
            ) : (
              <>
                <CheckCircle size={20} />
                Process Data
              </>
            )}
          </button>

          {result && (
            <button onClick={resetApp} className="btn btn-secondary">
              Reset
            </button>
          )}
        </div>

        {/* Error Message */}
        {error && (
          <div className="alert alert-error">
            <AlertCircle size={20} />
            <p>{error}</p>
          </div>
        )}

        {/* Loading State */}
        {loading && (
          <div className="loading-state">
            <div className="spinner"></div>
            <p>Processing your data...</p>
          </div>
        )}

        {/* Results */}
        {result && result.length > 0 && (
          <div className="results">
            <div className="results-header">
              <h2>Processing Results</h2>
              <button onClick={downloadOutput} className="btn btn-success">
                <Download size={20} />
                Download Output
              </button>
            </div>

            {result.map((item) => (
              <div key={item.company.id} className="company-card">
                {/* Company Header */}
                <div className="company-header">
                  <div className="company-info">
                    <div className="company-title">
                      <Building2 size={24} />
                      <h3>{item.company.name}</h3>
                    </div>
                    <p className="company-id">Company ID: {item.company.id}</p>
                  </div>
                  <div className="company-stats">
                    <div className="stat">
                      <span className="stat-label">Users</span>
                      <span className="stat-value">{item.users.length}</span>
                    </div>
                    <div className="stat">
                      <span className="stat-label">Total Top-ups</span>
                      <span className="stat-value">{item.total_top_up}</span>
                    </div>
                  </div>
                </div>

                {/* Users List */}
                <div className="users-list">
                  <h4>
                    <Users size={20} />
                    Users Emailed ({item.users.length})
                  </h4>
                  {item.users.map((user, idx) => (
                    <div key={idx} className="user-card">
                      <div className="user-header">
                        <div className="user-info">
                          <h5>
                            {user.last_name}, {user.first_name}
                          </h5>
                          <p>{user.email}</p>
                        </div>
                        <span
                          className={`badge ${
                            user.email_sent ? "badge-success" : "badge-gray"
                          }`}
                        >
                          {user.email_sent ? (
                            <>
                              <CheckCircle size={16} />
                              Email Sent
                            </>
                          ) : (
                            <>
                              <XCircle size={16} />
                              Email Not Sent
                            </>
                          )}
                        </span>
                      </div>
                      <div className="token-info">
                        <div className="token-item">
                          <span className="token-label">Previous Balance</span>
                          <span className="token-value">{user.tokens}</span>
                        </div>
                        <div className="token-item">
                          <span className="token-label">Top-up Amount</span>
                          <span className="token-value topup">
                            +{user.top_up_amount}
                          </span>
                        </div>
                        <div className="token-item">
                          <span className="token-label">New Balance</span>
                          <span className="token-value new">
                            {user.new_balance}
                          </span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Empty State */}
        {result && result.length === 0 && (
          <div className="alert alert-warning">
            <AlertCircle size={24} />
            <div>
              <h3>No Eligible Users Found</h3>
              <p>No active users matched the criteria for token top-ups.</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;
